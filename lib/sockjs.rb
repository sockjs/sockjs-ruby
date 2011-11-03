# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
  module CallbackMixin
    attr_accessor :status

    def callbacks
      @callbacks ||= Hash.new { |hash, key| hash[key] = Array.new }
    end
  end

  class CloseError < StandardError
    attr_reader :status, :message
    def initialize(status, message)
      @status, @message = status, message
    end
  end

  class Connection
    include CallbackMixin

    def initialize(&block)
      self.callbacks[:connect] << block
      self.status = :not_connected
    end

    def sessions
      @sessions ||= Hash.new
    end

    def subscribe(&block)
      self.callbacks[:subscribe] << block
    end

    def session_open(&block)
      self.callbacks[:session_open] << block
    end

    def create_session(key)
      self.sessions[key] ||= begin
        Session.new(open: callbacks[:session_open], message: callbacks[:subscribe])
      end
    end
  end

  class Session
    include CallbackMixin

    def initialize(callbacks)
      @callbacks = callbacks
    end

    def messages
      @messages ||= Array.new
    end

    def open!
      self.status = :opened
      self.execute_callback(:open, self)
      Protocol::OPEN_FRAME
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end

    def process_message
      self.execute_callback(:message, self.messages)
    end

    def close(status = 3000, message = "Go away!")
      raise SockJS::CloseError.new(status, message)
    end

    def send(message)
      self.messages << message
    end

    def execute_callback(name, *args)
      response do
        self.callbacks[name].each do |callback|
          callback.call(*args)
        end
      end
    end

    def messages
      @messages ||= Array.new
    end

    def response(&block)
      block.call

      response = Protocol.array_frame(messages)
      self.messages.clear
      return response
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end
  end
end
