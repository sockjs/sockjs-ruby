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

    def send_data(frame)
      if @response.nil?
        raise TypeError.new("@response must not be nil!")
      end

      @transport.send_data(@response, frame)
    end

    def send(*messages)
      self.buffer.push(*messages)
      self.send_data(self.buffer.to_frame)
      self.buffer.messages.clear
    end

    def finish
      # This is pretty hacky, but it gives us the choice
      # to "redefine" this method from transport classes.
      if @transport.respond_to?(:send_data)
        @transport.send_data(@response, @buffer.to_frame)
      else
        # TODO: this check should be done earlier:
        # initialize(transport, response, callbacks)
        # -> response can be nil only if transport.respond_to?(:send_data)
        if @response.nil?
          raise "You have to assign something to session.response!"
        end

        if @response.body.closed?
          puts "~ Response closed already #{caller.inspect}"
        else
          @response.finish(@buffer.to_frame)
        end
      end
    end

    # All incoming data is treated as incoming messages,
    # either single json-encoded messages or an array
    # of json-encoded messages, depending on transport.
    def receive_message(request, data)
      self.check_status
      self.reset_timer

      messages = parse_json(data)
      process_messages(*messages) unless messages.empty?
    rescue SockJS::InvalidJSON => error
      @transport.respond(request, error.status) do |response|
        response.write(error.message)
      end
    end

    def process_messages(*messages)
      @received_messages.push(*messages)
    end
    protected :process_messages

    def process_buffer(reset_timer = true)
      self.reset_timer if reset_timer

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
      # Shouldn't we set @buffer.status to :open?
      # Ah, apparently we can't, there's no API for it,
      # only by creating a new Buffer instance.
      if @status == :opening
        @status = :open
        self.execute_callback(:open, self)
      end
    end

    # TODO: what with the args?
    def open!(*args)
      @status = :opening
      self.set_timer

      self.buffer.open # @buffer.status to :opening
      self.finish
    end

    # Set the internal state to closing
    def close_session(status = 3000, message = "Go away")
      @status = :closing

      if self.buffer.closing?
        # This would be if we're resending closing frame on a closing session.
        # For such sessions we don't reset the buffer.
      else
        self.buffer.close(status, message)
      end
    end

    def close(status = 3000, message = "Go away!")
      # Hint: session.buffer = Buffer.new(:open) or so
      if self.newly_created?
        raise "You can't change from #{@status} to closing!"
      end

      self.close_session(status, message)

      self.finish

      self.reset_close_timer

      # Hint: session.buffer = Buffer.new(:open) or so
    rescue SockJS::StateMachineError => error
      raise error
    end

    def newly_created?
      @status == :created
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

    def init_timer(response, interval = 0.1)
      self.set_timer

      # Run the app at least once.
      data = self.run_user_app(response)

      if data && data[0] == "c" # TODO: Do this by raising an exception or something, this is a mess :o
        response.finish
      else
        init_periodic_timer(response, interval)
      end
    end

    def run_user_app(response)
      data = self.process_buffer(false)
      if data != "a[]"
        response_data = @transport.format_frame(data)
        puts "~ Responding with #{response_data.inspect}"
        response.write(response_data)
        return data
      else
        return nil
      end
    end

    def init_periodic_timer(response, interval)
      @periodic_timer = EM::PeriodicTimer.new(interval) do
        @periodic_timer.cancel if @disconnect_timer_canceled
        puts "~ Tick"

        unless @received_messages.empty?
          data = run_user_app(response)

          if data && data[0] == "c" # TODO: Do this by raising an exception or something, this is a mess :o
            @periodic_timer.cancel
            response.finish
          end
        end
      end
    end

    protected
    def parse_json(data)
      if data.empty?
        raise SockJS::InvalidJSON.new("Payload expected.")
      end

      JSON.parse(data)
    rescue JSON::ParserError => error
      raise SockJS::InvalidJSON.new("Broken JSON encoding.")
    end

    def set_timer
      puts "~ Setting @disconnect_timer to #{@disconnect_delay}"
      @disconnect_timer = begin
        EM::Timer.new(@disconnect_delay) do
          puts "~ #{@disconnect_delay} has passed, firing @disconnect_timer"
          @disconnect_timer_canceled = true

          if self.opening? or self.open?
            # OK, so we're here, closing the open response ... but its body is already closed, huh?
            puts "~ @disconnect_timer: closing the connection."
            self.close_session
            puts "~ @disconnect_timer: connection closed."
          else
            puts "~ @disconnect_timer: doing nothing."
          end
        end
      end
    end

    def reset_timer
      puts "~ Cancelling @disconnect_timer"
      @disconnect_timer.cancel if @disconnect_timer

      self.set_timer
    end

    def reset_close_timer
      if @close_timer
        puts "~ Cancelling @close_timer"
        @close_timer.cancel
      end

      puts "~ Setting @close_timer to #{@disconnect_delay}"

      @close_timer = EM::Timer.new(@disconnect_delay) do
        puts "~ @close_timer fired"
        @periodic_timer.cancel if @periodic_timer
        self.mark_to_be_garbage_collected
      end
    end

    def mark_to_be_garbage_collected
      puts "~ Closing the session"
      @status = :closed
    end
  end


  class SessionWitchCachedMessages < Session
    def send(*messages)
      self.buffer.push(*messages)
    end

    def finish
      data = @transport.format_frame(@buffer.to_frame)
      @response.finish(data)
    end
  end
end
