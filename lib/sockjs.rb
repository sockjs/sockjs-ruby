# encoding: utf-8

require "eventmachine"
require "forwardable"
require "sockjs/version"

module SockJS
  module CallbackMixin
    attr_accessor :status

    def callbacks
      @callbacks ||= Hash.new { |hash, key| hash[key] = Array.new }
    end

    def execute_callback(name, *args)
      if self.callbacks.has_key?(name)
        self.callbacks[name].each do |callback|
          callback.call(*args)
        end
      else
        raise ArgumentError.new("There's no callback #{name.inspect}. Available callbacks: #{self.callbacks.keys.inspect}")
      end
    end
  end

  class CloseError < StandardError
    attr_reader :status, :message
    def initialize(status, message)
      @status, @message = status, message
    end
  end

  class HttpError < StandardError
    attr_reader :status, :message

    # TODO: Refactor to (status, message, &block)
    def initialize(*args, &block)
      @message = args.last
      @status = (args.length >= 2) ? args.first : 500
      @block = block
    end

    def to_response(adapter, request)
      adapter.respond(request, self.status) do |response|
        response.set_content_type(:plain)
        @block.call(response) if @block
        response.write(self.message) if self.message
      end
    end
  end

  class InvalidJSON < HttpError
  end

  class Connection
    include CallbackMixin

    def initialize(&block)
      self.callbacks[:open] << block
      self.status = :not_connected

      self.execute_callback(:open, self)
    end

    def sessions
      puts "~ Refreshing sessions"

      if @sessions
        @sessions.delete_if do |_, session|
          if session.closed?
            puts "~ Removing closed session #{_}"
          end

          session.closed?
        end
      else
        @sessions = Hash.new
      end
    end

    def subscribe(&block)
      self.callbacks[:subscribe] << block
    end

    def session_open(&block)
      self.callbacks[:session_open] << block
    end

    def create_session(key, transport, session_class = transport.session_class)
      self.sessions[key] ||= begin
        session_class.new(transport, open: callbacks[:session_open], buffer: callbacks[:subscribe])
      end
    end
  end
end
