# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
  class CloseError < StandardError
    attr_reader :status, :message
    def initialize(status, message)
      @status, @message = status, message
    end
  end

  class Connection
    attr_accessor :status
    def initialize(&block)
      self.callbacks[:connect] = block
      self.status = :not_connected
    end

    def open!
      self.status = :opened
      self.callbacks[:connect].call(self)
    end

    def close!
      self.callbacks[:disconnect].each do |callback|
        callback.call
      end

      self.status = :closed
    end

    def sessions
      @sessions ||= Hash.new
    end

    def callbacks
      @callbacks ||= Hash.new
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

    def close(status = 3000, message = "Go away!")
      raise SockJS::CloseError.new(status, message)
    end

    def subscribe(&block)
      self.callbacks[:subscribe] ||= Array.new
      self.callbacks[:subscribe] << block
    end
  end
end
