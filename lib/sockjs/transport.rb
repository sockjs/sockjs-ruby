# encoding: utf-8

require "sockjs/buffer"
require "sockjs/session"
require "sockjs/servers/thin"

module SockJS
  class SessionUnavailableError < StandardError
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

    def response(request, status, options = Hash.new, &block)
      response = self.response_class.new(request, status)

      case block && block.arity
      when nil # no block
      when 1
        block.call(response)
      when 2
        if session = self.get_session(request.path_info)
          session.buffer = Buffer.new(:open)
        elsif session.nil? && options[:session] == :create
          session = self.create_session(request.path_info)
          session.buffer = Buffer.new
        end

        if session
          session.response = response
          block.call(response, session) # TODO: maybe it's better to do everything throught session, it knows response already anyway ... but sometimes we don't need   session, for instance in the welcome screen or iframe.
        else
          puts "~ Session can't be retrieved."
        end
      else
        raise ArgumentError.new("Block in response takes either 1 or 2 arguments!")
      end

      response
    end

    def respond(*args, &block)
      response(*args, &block).tap(&:finish)
    end

    # There's a session:
    #   a) It's closing -> Send c[3000,"Go away!"] AND END
    #   b) It's open:
    #      i) There IS NOT any consumer -> OK. AND CONTINUE
    #      i) There IS a consumer -> Send c[2010,"Another con still open"] AND END
    def get_session(path_info)
      match = path_info.match(self.class.prefix)

      if session = self.connection.sessions[match[1]]
        if session.closing?
          session.close(3000, "Session is closing")
          raise SessionUnavailableError.new("Session is closing")
        elsif (session.open? && session.response.nil?) || session.newly_created?
          return session
        elsif session.open? && session.response
          puts "~ Another connection still open"
          session.close(2010, "Another connection still open")
          raise SessionUnavailableError.new("Another connection still open")
        end
      else
        puts "~ Session #{match[1].inspect} hasn't been created yet."
        return nil
      end
    end

    def create_session(path_info, response = nil, preamble = nil)
      response.write(preamble) if preamble

      match = path_info.match(self.class.prefix)

      return self.connection.create_session(match[1], self)
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
