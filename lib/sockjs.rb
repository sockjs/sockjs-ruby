# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
  class Connection
    def initialize(&block)
      block.call(self)
    end

    # Does it have to be EM-based?
    # So the request comes and then ... well this is actually synchronous stuff!
    # On the other hand ... we need to share with em-websocket ... ?
    def post_init
    end

    def receive_data(data)
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
