# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
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

    def retrieve_messages
      self.messages.tap do |messages|
        messages.clear
      end
    end

    def close(status = 3000, message = "Go away!")
      warn "~ SockJS::Connection#close"
    end

    def subscribe(&block)
      self.callbacks[:subscribe] ||= Array.new
      self.callbacks[:subscribe] << block
    end
  end
end
