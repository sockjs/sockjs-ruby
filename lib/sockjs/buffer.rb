# encoding: utf-8

require "sockjs/protocol"

module SockJS
  class BufferNotOpenError < StandardError
    def initialize(status)
      super("Buffer is #{status}, not open!")
    end
  end

  class StateMachineError < StandardError
    def initialize(actual_status, aim_status)
      super("Can't change from #{actual_status} to #{aim_status}!")
    end
  end

  class Buffer
    attr_reader :messages

    PERMITTED_STATUS_NAMES ||= begin
      [:newly_created, :open, :opening, :closing, :closed]
    end

    # There's a new buffer instance created for every new request,
    # so we must not forget to set the proper state for every one.
    def initialize(status = :newly_created)
      @status, @messages = status, Array.new

      unless PERMITTED_STATUS_NAMES.include?(status)
        raise ArgumentError.new("Status must be one of #{PERMITTED_STATUS_NAMES.inspect} (#{status.inspect} given).")
      end
    end

    # To get the data encoded as a SockJS frame.
    def to_frame
      if self.opening? or self.closing?
        @frame
      else
        Protocol.array_frame(@messages)
      end
    end


    # === Status changing methods. === #

    # Open frame has to be the first frame.
    def open
      if self.newly_created?
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
    def close(status, message)
      # Beware of discarding messages with primitive transports.
      #
      # For instance:
      #   session.send("I love SockJS!")
      #   session.close(1212, "I'm a bit bored now.")
      #
      # With advanced transports such as WebSockets,
      # everything is fine, the first message will be
      # delivered and then the closing frame will be send.
      # However with primitive transports such as long
      # polling, only the closing frame will be send.
      if self.opening? or self.open? or self.closing?
        @status = :closing
        @frame  = Protocol.closing_frame(status, message)
      else
        raise StateMachineError.new(@status, :closing)
      end
    end


    # === Methods manipulating messages. === #

    # Add message to the list of messages.
    def <<(message)
      raise BufferNotOpenError.new(@status) unless self.open?
      @messages << message
    end

    def push(*messages)
      messages.each do |message|
        self << message
      end
    end


    # === Status reporting methods. === #

    def newly_created?
      @status == :newly_created
    end

    def opening?
      @status == :opening
    end

    def open?
      @status == :open
    end

    def closing?
      @status == :closing
    end

    def closed?
      @status == :closed
    end
  end
end
