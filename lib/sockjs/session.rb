# encoding: utf-8

module SockJS
  class Session
    include CallbackMixin

    attr_accessor :buffer, :response

    def initialize(transport, callbacks)
      @transport = transport
      @callbacks = callbacks
      @disconnect_delay = 5 # TODO: make this configurable.
      @status = :created
      @received_messages = Array.new
    end

    def send(data, *args)
      @buffer << @transport.format_frame(data, *args)
    end

    def finish
      # This is pretty hacky, but it gives us the choice
      # to "redefine" this method from transport classes.
      if @transport.respond_to?(:session_finish)
        @transport.session_finish
      else
        # TODO: this check should be done earlier:
        # initialize(transport, response, callbacks)
        # -> response can be nil only if transport.respond_to?(:session_finish)
        if @response.nil?
          raise "You have to assign something to session.response!"
        end

        @response.finish(@buffer.to_frame)
      end
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

      create_response do
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

    def create_response(&block)
      block.call

      @received_messages.clear
      @buffer.to_frame
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
      # Hint: session.buffer = Buffer.new(:open) or so
      if self.status == :created
        raise "You can't change from #{self.status} to closing!"
      end

      self.status = :closing

      self.buffer.close(status, message)
      self.finish

      self.reset_close_timer

      # Hint: session.buffer = Buffer.new(:open) or so
    rescue SockJS::StateMachineError => error
      raise error
    end

    def newly_created?
      @status == :created
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

    def reset_close_timer
      @close_timer.cancel if @close_timer

      @close_timer = EM::Timer.new(@disconnect_delay) do
        self.mark_to_be_garbage_collected
      end
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
