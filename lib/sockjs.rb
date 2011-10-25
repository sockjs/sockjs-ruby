# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"

module SockJS
  def self.connect(options = Hash.new)
    host = options[:host] || "127.0.0.1"
    port = options[:port] || 9999
    EventMachine.connect(host, port, Connection, options)
  end

  def self.start(options = Hash.new, &block)
    EM.run do
      block.call(self.connect(options))
    end
  end

  module Connection
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

    def subscribe(&block)
      self.callbacks[:subscribe] ||= Array.new
      self.callbacks[:subscribe] << block
    end
  end
end
