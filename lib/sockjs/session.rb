# encoding: utf-8

require "forwardable"

module SockJS
  class Session
    extend Forwardable

    include CallbackMixin

    def_delegator :@transport, :send
    def_delegator :@transport, :finish
    def_delegator :@transport, :buffer

    def initialize(transport, callbacks)
      @transport = transport
      @callbacks = callbacks
      @disconnect_delay = 5 # TODO: make this configurable.
      @status = :created
      @received_messages = Array.new
    end

    # All incoming data is treated as incoming messages,
    # either single json-encoded messages or an array
    # of json-encoded messages, depending on transport.
    def receive_message(data)
      self.check_status
      self.reset_timer

      # Weelll ... "string" is not a valid JSON.
      # However SockJS already work with this,
      # so let's make it compatible.
      unless data.match(/^\[.*\]$/)
        data = "[#{data}]"
      end

      process_messages(*parse_json(data))
    end

    def process_messages(*messages)
      @received_messages.push(*messages)
    end

    def process_buffer
      self.reset_timer

      response do
        self.check_status

        # The error is supposed to be cached for 5s
        # in case the connection dies. For the time
        # being we cache it infinitely.
        raise @error if @error

        @received_messages.each do |message|
          self.execute_callback(:buffer, self, message)
        end
      end
    end

    def response(&block)
      block.call

      @received_messages.clear
      @transport.buffer.to_frame
    rescue SockJS::CloseError => error
      Protocol.closing_frame(error.status, error.message)
    end

    def check_status
      if @status == :opening
        @status = :open
        self.execute_callback(:open, self)
      end
    end

    def open!(*args)
      self.status = :opening
      self.set_timer

      self.buffer.open
      self.finish
    end

    def close(status = 3000, message = "Go away!")
      if self.status == :created
        raise "You can't change from #{self.status} to closing!"
      end

      self.status = :closing

      self.buffer.close(status, message)
      self.finish

      @close_timer.cancel if @close_timer

      @close_timer = EM::Timer.new(@disconnect_delay) do
        self.mark_to_be_garbage_collected
      end
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

    protected
    def parse_json(data)
      raise EmptyPayload.new if data == "[]"
      JSON.parse(data)
    rescue JSON::ParserError => error
      raise SockJS::InvalidJSON.new(error.message)
    end

    def set_timer
      @disconnect_timer = begin
        EM::Timer.new(@disconnect_delay) do
          unless self.closed? or self.closing?
            puts "~ Closing the connection."
            self.close
            puts "~ Connection closed."
          end
        end
      end
    end

    def reset_timer
      @disconnect_timer.cancel
      self.set_timer
    end

    def mark_to_be_garbage_collected
      @status = :closed
    end
  end

  class SessionWitchCachedMessages < Session
    def send(*messages)
      self.buffer.push(*messages)
    end

    def finish
      self.buffer.to_frame
    end
  end
end
