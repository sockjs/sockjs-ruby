# encoding: utf-8

require "sockjs/buffer"

module SockJS
  class Adapter
    CONTENT_TYPES ||= {
      plain: "text/plain; charset=UTF-8",
      html: "text/html; charset=UTF-8",
      javascript: "application/javascript; charset=UTF-8",
      event_stream: "text/event-stream; charset=UTF-8"
    }

    class << self
      attr_accessor :prefix, :method, :subclasses, :session_class
    end

    self.method        ||= "GET"
    self.subclasses    ||= Array.new
    self.session_class ||= SessionWitchCachedMessages

    # TODO: refactor the following two methods: just find the prefix and check the method later on, so we won't need the second method at all.
    def self.handler(prefix, method)
      self.subclasses.find do |handler|
        handler.prefix === prefix && handler.method == method
      end
    end

    def self.match_handler_for_http_405(prefix, method)
      self.subclasses.find do |handler|
        handler.prefix === prefix && handler.method != method
      end
    end

    def self.inherited(subclass)
      Adapter.subclasses << subclass

      subclass.method        = self.method
      subclass.prefix        = self.prefix
      subclass.session_class = self.session_class
    end

    # Instance methods.
    attr_reader :connection, :options, :buffer
    def initialize(connection, options)
      @connection, @options, @buffer = connection, options, Buffer.new
    end

    def disabled?
      disabled_transports = @options[:disabled_transports] || Array.new
      return disabled_transports.include?(self.class)
    end

    # TODO: Make it use the adapter user uses.
    def response_class
      SockJS::Thin::Response
    end

    def response(*args, &block)
      @response ||= self.response_class.new(*args, &block)
    end

    def write_response(request, status, headers, body, &block)
      self.response(request, status, headers, &block)
      @response.write_head
      @response.write(body) unless body.nil?
      @response.finish
      return @response
    end

    def format_frame(payload)
      "#{payload}\n"
    end

    def send(data, *args)
      @buffer << self.format_frame(data, *args)
    end

    def finish
      @response.finish(@buffer.to_frame)
    end

    def respond(request, status, options = Hash.new, &block)
      response = self.response(request, status)

      if options[:set_session_id]
        response.set_session_id(request.session_id)
      end

      session = self.get_session(request, response) # TODO: preamble
      @buffer = session ? Buffer.new(:opened) : Buffer.new # TODO: don't set buffer twice!
      block.call(response, session)
    end

    def error(http_status, content_type, body)
      raise NotImplementedError.new("TODO: Implement Adapter#error")
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
          if data[0] == "c" # close frame. TODO: Do this by raising an exception or something, this is a mess :o Actually ... do we need here some 5s timeout as well?
            timer.cancel
            response.finish
          end
        end
      end
    end
  end
end
