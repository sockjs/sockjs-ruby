# encoding: utf-8

require "sockjs/buffer"
require "sockjs/session"
require "sockjs/servers/thin"

module SockJS
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
    end

    def disabled?
      disabled_transports = @options[:disabled_transports] || Array.new
      return disabled_transports.include?(self.class)
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

    def response(request, status, &block)
      response = self.response_class.new(request, status)

      case block.arity
      when 1
        block.call(response)
      when 2
        session = self.get_session(request, response) # TODO: preamble
        session.buffer = session ? Buffer.new(:open) : Buffer.new
        session.response = response
        block.call(response, session) # TODO: maybe it's better to do everything throught session, it knows response already anyway ... but sometimes we don't need   session, for instance in the welcome screen or iframe.
      else
        raise ArgumentError.new("Block in response takes either 1 or 2 arguments!")
      end

      response
    end

    def respond(*args, &block)
      response(*args, &block).tap(&:finish)
    end

    # 1) There's no session -> create it. AND CONTINUE
    # 2) There's a session:
    #    a) It's closing -> Send c[3000,"Go away!"] AND END
    #    b) It's open:
    #       i) There IS NOT any consumer -> OK. AND CONTINUE
    #       i) There IS a consumer -> Send c[2010,"Another con still open"] AND END
    def get_session(request, response, preamble = nil)
      match = request.path_info.match(self.class.prefix)

      if session = self.connection.sessions[match[1]]
        if session.closing?
          session.close
          return nil
        elsif session.open? && session.response.nil?
          return session
        elsif session.open? && session.response
          session.close(2010, "Another connection still open")
          return nil
        end
      else
        response.write(preamble) if preamble

        session = self.connection.create_session(match[1], self)
        session.open!
        return session
      end
    end

    def try_timer_if_valid(request, response, preamble = nil)
      session = self.get_session(request, response, preamble)
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
