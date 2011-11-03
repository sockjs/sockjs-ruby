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

  class Connection
    include CallbackMixin

    def initialize(&block)
      self.callbacks[:open] << block
      self.status = :not_connected

      self.execute_callback(:open, self)
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
        # raise 'create_session: ' + callbacks.inspect
        #  So we don't get subscribe callback because open clbk is never called
        Session.new(open: callbacks[:session_open], buffer: callbacks[:subscribe])
      end
    end
  end

  class Session
    include CallbackMixin

    def initialize(callbacks)
      @callbacks = callbacks
      @received_messages = Array.new
      @messages_for_the_client = Array.new

      self.execute_callback(:open, self)
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

      @received_messages.push(*JSON.parse(data))
    end

    def open!
      self.status = :opened
      self.execute_callback(:open, self)
      Protocol::OPEN_FRAME
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end

    def process_buffer
      response do
        @received_messages.each do |message|
          self.execute_callback(:buffer, self, message)
        end

        @messages_for_the_client
      end
    end

    def close(status = 3000, message = "Go away!")
      raise SockJS::CloseError.new(status, message)
    end

    def send(*messages)
      @messages_for_the_client.push(*messages)
    end

    def response(&block)
      block.call

      Protocol.array_frame(@messages_for_the_client).tap do |_|
        @messages_for_the_client.clear
        @received_messages.clear
      end
    rescue SockJS::CloseError => error
      Protocol.close_frame(error.status, error.message)
    end
  end
end
