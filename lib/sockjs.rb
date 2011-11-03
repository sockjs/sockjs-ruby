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
        Session.new(open: callbacks[:session_open], buffer: callbacks[:subscribe])
      end
    end
  end

  class Session
    include CallbackMixin

    def initialize(callbacks)
      @callbacks = callbacks
      @messages  = Array.new
    end

    # All incoming data is treated as incoming messages,
    # either single json-encoded messages or an array
    # of json-encoded messages, depending on transport.
    def receive_message(data)
      # Weelll ... "string" is not a valid JSON.
      # However SockJS already work with this,
      # so let's make it compatible.
      unless data.match(/^\[.*\]$/)
        data = "[#{data}]"
      end

      @messages.push(*JSON.parse(data))
    end

    def open!
      self.status = :opened
      self.execute_callback(:open, self)
      Protocol::OPEN_FRAME
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end

    def process_buffer
      self.execute_callback(:buffer, @messages)
    end

    def close(status = 3000, message = "Go away!")
      raise SockJS::CloseError.new(status, message)
    end

    def send(message)
      @messages << message
    end

    def execute_callback(name, *args)
      response do
        self.callbacks[name].each do |callback|
          callback.call(*args)
        end
      end
    end

    def response(&block)
      block.call

      Protocol.array_frame(@messages).tap do |_|
        @messages.clear
      end
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end
  end
end
