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
      self.callbacks[name].each do |callback|
        callback.call(*args)
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
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def to_response(adapter, request)
      adapter.write_response(request, 500, {"Content-Type" => "text/plain"}, self.message)
    end
  end

  class InvalidJSON < HttpError
    def initialize(*)
      @message = "Broken JSON encoding."
    end
  end

  class EmptyPayload < HttpError
    def initialize(*)
      @message = "Payload expected."
    end
  end

  class Connection
    include CallbackMixin

    def initialize(&block)
      self.callbacks[:open] << block
      self.status = :not_connected

      self.execute_callback(:open, self)
    end

    def sessions
      if @sessions
        @sessions.delete_if do |_, session|
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

    def create_session(key, transport)
      self.sessions[key] ||= begin
        transport.class.session_class.new(transport, open: callbacks[:session_open], buffer: callbacks[:subscribe])
      end
    end
  end
end
