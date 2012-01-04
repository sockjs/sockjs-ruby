# encoding: utf-8

require "sockjs/protocol"

module SockJS
  class BufferNotOpenError < StandardError
    def initialize(*)
      super("Buffer isn't open!")
    end
  end

  class StateMachineError < StandardError
    def initialize(actual_status, aim_status)
      super("Can't change from #{actual_status} to #{aim_status}!")
    end
  end

  class Buffer
    # There's a new buffer instance created for every new request,
    # so we must not forget to set the proper state for every one.
    def initialize(status = nil)
      @status, @messages = status, Array.new
    end

    # Open frame has to be the first frame.
    def open
      unless @messages.empty?
        raise "You can't send any messages before sending the open frame!"
      end

      if @status == nil
        @status = :opening
        @frame  = Protocol::OPENING_FRAME
      else
        raise StateMachineError.new(@status, :opening)
      end
    end

    # Close frame can occur at any time, except if
    # the session isn't open yet. Also, if the buffer
    # is already closed, let's fail: I believe this
    # is a more transparent behaviour.
    def close(*args)
      # Beware of discarding messages with primitive transports.
      #
      # For instance:
      #   session.send("I love SockJS!")
      #   session.close(1212, "I'm a bit bored now.")
      #
      # With advanced transports such as WebSockets,
      # everything is fine, the first message will be
      # delivered and then the close frame will be send.
      # However with primitive transports such as long
      # polling, only the close frame will be send.
      if @status == :open
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

    def push(*messages)
      messages.each do |message|
        self << message
      end
    end

    # In case you need to rewrite content of
    # the buffer, you can do so calling #clear.
    def clear
      @frame = nil; @messages.clear
    end

    # To get the data encoded as a SockJS frame.
    def to_frame
      @frame || Protocol.array_frame(@messages)
    end
  end
end
