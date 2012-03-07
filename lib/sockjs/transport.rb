# encoding: utf-8

require "sockjs/buffer"
require "sockjs/session"
require "sockjs/servers/thin"

module SockJS
  class SessionUnavailableError < StandardError
    attr_reader :status, :session

    def initialize(session, status = session.last_frame_status, message = session.last_frame_message)
      @session, @status, @message = session, status, message
    end
  end

  class Transport
    # @deprecated: See response.rb
    CONTENT_TYPES ||= {
      plain: "text/plain; charset=UTF-8",
      html: "text/html; charset=UTF-8",
      javascript: "application/javascript; charset=UTF-8",
      event_stream: "text/event-stream; charset=UTF-8"
    }

    class << self
      attr_accessor :prefix, :method, :subclasses
    end

    self.method     ||= "GET"
    self.subclasses ||= Array.new

    def self.handlers(prefix)
      self.subclasses.select do |subclass|
        subclass.prefix === prefix
      end
    end

    def self.inherited(subclass)
      Transport.subclasses << subclass

      subclass.method = self.method
      subclass.prefix = self.prefix
    end

    # Instance methods.
    attr_reader :connection, :options
    def initialize(connection, options)
      @connection, @options = connection, options
      options[:websocket] = true unless options.has_key?(:websocket)
      options[:cookie_needed] = true unless options.has_key?(:cookie_needed)
    end

    def session_class
      SockJS::SessionWitchCachedMessages
    end

    # TODO: Make it use the adapter user uses.
    def response_class
      SockJS::Thin::Response
    end

    def format_frame(payload)
      raise TypeError.new if payload.nil?

      "#{payload}\n"
    end

    def response(request, status, options = Hash.new, &block)
      response = self.response_class.new(request, status)
      p [:resp_body, response.body.instance_variable_get(:@status)]
      # Here everything's fine, the sky is shining, the sun is singing and the birds are blue. Or is it the other way round?

      case block && block.arity
      when nil # no block
      when 1
        block.call(response)
      when 2
        begin
          if session = self.get_session(request.path_info)
            session.buffer = Buffer.new(:open)
          elsif session.nil? && options[:session] == :create
            session = self.create_session(request.path_info)
            session.buffer = Buffer.new
          end

          if session
            session.response = response
            block.call(response, session) # TODO: maybe it's better to do everything through session, it knows response already anyway ... but sometimes we don't need session, for instance in the welcome screen or iframe.
          else
            puts "~ Session can't be retrieved."

            # This helps with identifying open connections.
            session.response = nil
          end
        rescue SockJS::SessionUnavailableError => error
          puts "~ SessionUnavailableError: #{error.message}"
          # response.body is closed at this point. WTF?
          error.session.close(error.status, error.message) # It fails here, because the session is closed already.

          # TODO: What shall we do about it? We need to call session.close
          # so we can send the closing frame with a DIFFERENT message.

          # Noooo, we don't need to call session.close, do we? We just need to send the bloody closing frame, huh?

          # Aaaaactually we DO, because we have to reset the bloody @close_timer!

          # This helps with identifying open connections.
          session.response = nil
        end
      else
        raise ArgumentError.new("Block in response takes either 1 or 2 arguments!")
      end

      response
    end

    def respond(*args, &block)
      response = response(*args, &block)
      response.finish unless response.body.closed?
      response
    end

    # There's a session:
    #   a) It's closing -> Send c[3000,"Go away!"] AND END
    #   b) It's open:
    #      i) There IS NOT any consumer -> OK. AND CONTINUE
    #      i) There IS a consumer -> Send c[2010,"Another con still open"] AND END
    def get_session(path_info, *) # TODO: process optional arguments.
      match = path_info.match(self.class.prefix)

      if session = self.connection.sessions[match[1]]
        if session.closing?
          # response.body is closed, why?
          puts "~ get_session: session is closing"
          raise SessionUnavailableError.new(session)
        elsif session.open? || session.newly_created? || session.opening?
          puts "~ get_session: session retrieved successfully"
          return session
        # TODO: Should be alright now, check 6aeeaf1fd69c
        # elsif session.response # THIS is an utter piece of sssshhh ... of course there's a response once we open it!
        #   puts "~ get_session: another connection still open"
        #   raise SessionUnavailableError.new(session, 2010, "Another connection still open")
        else
          raise "We should never get here!\nsession.status: #{session.instance_variable_get(:@status)}, has session response: #{!! session.response}"
        end
      else
        puts "~ get_session: session #{match[1].inspect} doesn't exist."
        return nil
      end
    end

    def create_session(path_info, response = nil, preamble = nil)
      response.write(preamble) if preamble

      match = path_info.match(self.class.prefix)

      return self.connection.create_session(match[1], self)
    end

    def try_timer_if_valid(request, response, preamble = nil)
      session = self.get_session(request.path_info, response, preamble)
      self.init_timer(response, session, 0.1) if session
    end

    def init_timer(response, session, interval)
      timer = EM::PeriodicTimer.new(interval) do
        if data = session.process_buffer
          response_data = format_frame(data.chomp!)
          puts "~ Responding with #{response_data.inspect}"
          response.write(response_data) unless data == "a[]\n" # FIXME
          if data[0] == "c" # closing frame. TODO: Do this by raising an exception or something, this is a mess :o Actually ... do we need here some 5s timeout as well?
            timer.cancel
            response.finish
          end
        end
      end
    end
  end
end
