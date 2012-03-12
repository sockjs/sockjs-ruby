# encoding: utf-8

module SockJS
  class Session
    include CallbackMixin

    attr_accessor :buffer, :response, :transport

    def initialize(callbacks)
      @callbacks = callbacks
      @disconnect_delay = 5 # TODO: make this configurable.
      @status = :created
      @received_messages = Array.new
    end

    def send_data(frame)
      if @transport.respond_to?(:send_data) # WebSocket
        return @transport.send_data(frame)
      end

      if @response.nil?
        raise TypeError.new("@response must not be nil!")
      end

      data = @transport.format_frame(frame)
      @response.write(data)

      # So we can resend closing frame.
      unless self.closing?
        self.buffer.clear
      end
    end

    def send(*messages)
      self.buffer.push(*messages)
      self.send_data(self.buffer.to_frame)
    end

    def finish
      self.send_data(@buffer.to_frame)
    end

    def with_response_and_transport(response, transport, &block)
      puts "~ with_response: assigning response and #{transport.class} ..."
      @response, @transport = response, transport
      block.call
    end

    def close_response
      @response = nil; @transport = nil
      puts "~ close_response: clearing response and transport."
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

    def after_app_run
    end

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

        self.after_app_run
      end
    end

    def create_response(&block)
      block.call

      @received_messages.clear

      if @buffer.contains_data?
        @buffer.to_frame.tap do
          @buffer.clear unless self.closing?
        end
      else
        nil
      end
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

      self.buffer.close(status, message)
    end

    def close(status = 3000, message = "Go away!")
      # Hint: session.buffer = Buffer.new(:open) or so
      if self.newly_created?
        raise "You can't change from #{@status} to closing!"
      end

      unless self.closing?
        self.close_session(status, message)
      end

      if @periodic_timer
        @periodic_timer.cancel
        @periodic_timer = nil
      end

      self.finish

      if @response # WS
        @response.write("") unless @response.body.closed? # Http11.test_streaming
      end

      self.close_response

      self.reset_close_timer

      # Hint: session.buffer = Buffer.new(:open) or so
    rescue SockJS::StateMachineError => error
      raise error
    end

    def waiting? # TODO: What about WS?
      !! @periodic_timer
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

    def wait(response, interval = 0.1)
      self.set_timer

      if self.waiting?
        self.close(2010, "Another connection still open")
      end

      # Run the app at least once.
      data = self.run_user_app(response)

      unless @buffer.closing?
        init_periodic_timer(response, interval)
      end
    end

    def run_user_app(response)
      frame = self.process_buffer(false)
      self.send_data(frame) if frame
    end

    def init_periodic_timer(response, interval)
      @periodic_timer = EM::PeriodicTimer.new(interval) do
        @periodic_timer.cancel if @disconnect_timer_canceled
        puts "~ Tick"

        unless @received_messages.empty?
          run_user_app(response)
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

    def send_data(frame)
      super(frame)

      @response.finish
    end

    alias_method :after_app_run, :finish

    def with_response_and_transport(response, transport, &block)
      super(response, transport, &block)
      self.close_response
    end
  end
end
