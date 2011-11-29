# encoding: utf-8

module SockJS
  class Adapter
    CONTENT_TYPES ||= {
      plain: "text/plain; charset=UTF-8",
      html: "text/html; charset=UTF-8",
      javascript: "application/javascript; charset=UTF-8",
      event_stream: "text/event-stream; charset=UTF-8"
    }

    class << self
      attr_accessor :prefix, :method, :filters, :subclasses
    end

    self.method     ||= "GET"
    self.subclasses ||= Array.new
    self.filters    ||= Array.new

    def self.handler(prefix, method)
      self.subclasses.find do |handler|
        handler.prefix === prefix && handler.method == method
      end
    end

    def self.inherited(subclass)
      Adapter.subclasses << subclass
      subclass.filters = Array.new

      subclass.method  = self.method
      subclass.prefix  = self.prefix
      subclass.filters = self.filters
    end

    # Instance methods.
    attr_reader :connection, :options
    def initialize(connection, options)
      @connection, @options = connection, options
    end

    # TODO: Make it use the adapter user uses.
    def response_class
      SockJS::Thin::Response
    end

    def response(*args, &block)
      @response ||= self.response_class.new(*args, &block)
    end

    def write_response(request, status, headers, body, &block)
      response = self.response(request, status, headers, &block)
      response.write_head
      response.write(body)
      response.finish
      return response
    end

    def send_frame(payload)
      payload
    end
  end
end
