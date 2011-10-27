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

    def execute_callback(name, *args)
      response do
        self.callbacks[name].each do |callback|
          callback.call(*args)
        end
      end
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
  end

  class Session
    include CallbackMixin

    def open!
      self.status = :opened
      self.execute_callback(:connect, self)
      Protocol::OPEN_FRAME
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end

    def close!
      self.status = :closing
      self.execute_callback(:disconnect)
    end

    def close(status = 3000, message = "Go away!")
      raise SockJS::CloseError.new(status, message)
    end

    def messages
      @messages ||= Array.new
    end

    def send(message)
      self.messages << message
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
