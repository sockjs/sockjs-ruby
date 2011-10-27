# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
  class Connection
    attr_accessor :status
    def initialize(&block)
      self.callbacks[:connect] = block
    end

    def open!
      self.state = :opened
      self.callbacks[:connect].call(self)
    end

    def close!
      self.callbacks[:disconnect].each do |callback|
        callback.call
      end

      self.state = :closed
    end

    def sessions
      @sessions ||= Hash.new
    end

    def callbacks
      @callbacks ||= Hash.new
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
