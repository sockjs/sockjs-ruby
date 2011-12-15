# encoding: utf-8

require "sockjs/protocol"

class SockJS
  class BufferNotOpenError < StandardError
  end

  class StandardError < StandardError
    def initialize(actual_status, aim_status)
      super("Can't change from #{actual_status} to #{aim_status}!")
    end
  end

  class Buffer
    def initialize
      @status, @messages = :created, Array.new
    end

    # Open frame has to be the first frame.
    def open
      if @status == :created
        @status = :opened
        @frame  = Protocol::OPEN_FRAME
      else
        raise StateMachineError.new(@status, :opened)
      end
    end

    # Close frame can occur at any time, except if the session isn't open yet.
    # Also, if the buffer is already closed, let's fail: I believe this is more transparent behaviour.
    def close(*args)
      unless @status == :created or @status == :closed
        @status = :closed
        @frame  = Protocol.close_frame(*args)
      else
        raise StateMachineError.new(@status, :closed)
      end
    end

    # Add message to the list of messages.
    def <<(message)
      raise BufferNotOpenError.new if @frame
      @messages << message
    end

    # In case you need to rewrite content of the buffer, you can do so calling #clear.
    def clear
      @frame = nil; @messages.clear
    end

    # To get the data encoded as a SockJS frame.
    def to_frame
      @frame || Protocol.array_frame(@messages)
    end
  end
end
