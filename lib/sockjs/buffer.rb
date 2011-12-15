# encoding: utf-8

require "sockjs/protocol"

class SockJS
  class BufferClosedError < StandardError
  end

  class Buffer
    def initialize
      @messages = Array.new
    end

    def close(*args)
      @frame = Protocol.close_frame(*args)
    end

    def <<(message)
      raise BufferClosedError.new if @frame
      @messages << message
    end

    def to_frame
      @frame || Protocol.array_frame(@messages)
    end
  end
end
