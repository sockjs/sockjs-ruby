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
      @total_sent_content_length = 0
    end

    def send_data(frame)
      if @response.nil?
        raise TypeError.new("Session#response must not be nil! Occurred when writing #{frame.inspect}")
      end

      data = @transport.format_frame(frame)

      @total_sent_content_length += data.bytesize

      @response.write(data)

      # So we can resend closing frame.
      unless self.closing?
        self.buffer.clear
      end
    end

    def send(*messages)
      return if messages.empty?
      self.buffer.push(*messages)
      self.send_data(self.buffer.to_frame)
    end

    def finish(no_content = false)
      frame = @buffer.to_frame
      self.send_data(frame)
    rescue SockJS::NoContentError => error
      if no_content
        puts "~ No content, it's fine though."
      else
        self.set_heartbeat_timer(error.buffer)
      end
    ensure
      @response.finish if @response && ((frame and frame.match(/^c\[\d+,/)) || no_content)
    end

    def with_response_and_transport(response, transport, &block)
      raise ArgumentError.new("Response must not be nil!") if response.nil?
      raise ArgumentError.new("Transport must not be nil!") if transport.nil?

      puts "~ with_response: assigning response and #{transport.class} (#{transport.object_id}) ..."

      if @transport && (@transport.is_a?(SockJS::Transports::XHRStreamingPost) || @transport.is_a?(SockJS::Transports::EventSource) || @transport.is_a?(SockJS::Transports::HTMLFile))
        puts "~ with_response: saving response and transport #{@transport.class} (#{@transport.object_id})"
        prev_resp, prev_trans = @response, @transport
      end

      @response, @transport = response, transport
      block.call

      if prev_trans && (prev_trans.is_a?(SockJS::Transports::XHRStreamingPost) || prev_trans.is_a?(SockJS::Transports::EventSource) || prev_trans.is_a?(SockJS::Transports::HTMLFile)) # TODO: #streaming? / #polling? / #waiting? ... actually no, just define this only for this class, the other transports use SessionWitchCachedMessages (but don't forget that it inherits from this one).
        puts "~ with_response: reassigning response and #{prev_trans.class} (#{prev_trans.object_id}) ..."
        @response, @transport = prev_resp, prev_trans
      end
    end

    def close_response
      puts "~ close_response: clearing response and transport."

      @response.finish
      @response = nil; @transport = nil
    end

    # All incoming data is treated as incoming messages,
    # either single json-encoded messages or an array
    # of json-encoded messages, depending on transport.
    def receive_message(request, data)
      self.reset_timer do
        self.check_status

        messages = parse_json(data)
        process_messages(*messages) unless messages.empty?
      end
    rescue SockJS::InvalidJSON => error
      raise error if @response.nil? # WS
      @transport.response(request, error.status) do |response|
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
      if @transport.nil?
        raise TypeError.new("Transport must not be nil!")
      end

      create_response(reset_timer) do
        puts "~ Processing buffer using #{@transport.class}"
        self.check_status

        # The error is supposed to be cached for 5s
        # in case the connection dies. For the time
        # being we cache it infinitely.
        raise @error if @error

        # Hmmm that's bollocks, what if we do session.close
        # from within the app? We can't call it multiple times,
        # unless we redefine session.close to raise an exception,
        # hence it wouldn't be executed only once ...
        # that's not a bad idea BTW.
        @received_messages.each do |message|
          puts "~ Executing app with message #{message.inspect}"
          self.execute_callback(:buffer, self, message)
        end

        self.after_app_run
      end
    end

    def create_response(reset_timer = true, &block)
      if reset_timer
        reset_timer { block.call }
      else
        block.call
      end

      @received_messages.clear

      if @buffer.contains_data?
        @buffer.to_frame.tap do
          @buffer.clear unless self.closing?
        end
      else
        nil
      end
    rescue SockJS::NoContentError => error
      self.set_heartbeat_timer(error.buffer)
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
      self.buffer.open # @buffer.status to :opening

      self.set_timer
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

      if not self.closing?
        self.close_session(status, message)
      end

      if @periodic_timer
        @periodic_timer.cancel
        @periodic_timer = nil
      end

      # SessionWitchCachedMessages#after_app_run is aliased to #finish
      # and we MUST NOT clear the buffer, because we have to cache it
      # for the next responses. Bugger ...
      self.finish if self.class == SockJS::Session

      self.reset_close_timer

      # Hint: session.buffer = Buffer.new(:open) or so
    rescue SockJS::StateMachineError => error
      raise error
    end

    def on_close
      puts "~ The connection has been closed on the client side (current status: #{@status})."
      self.close_session(1002, "Connection interrupted")
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
      if self.waiting? # Doesn't work for XHR, only for streaming.
        puts "~ Session#wait: another connection still open"
        self.close(2010, "Another connection still open")
        return
      end

      # Run the app at least once.
      data = self.run_user_app(response)

      self.set_timer

      unless @buffer.closing?
        init_periodic_timer(response, interval)
      end
    end

    def max_permitted_content_length
      $DEBUG ? 4096 : 128_000
    end

    def run_user_app(response)
      puts "~ Executing user's SockJS app"
      frame = self.process_buffer(false)
      self.send_data(frame) if frame and not frame.match(/^c\[\d+,/)
      puts "~ User's SockJS app finished"
    end

    def init_periodic_timer(response, interval)
      @periodic_timer = EM::PeriodicTimer.new(interval) do
        @periodic_timer.cancel if @disconnect_timer_canceled
        puts "~ Tick: #{@status}, #{@buffer.inspect}"

        unless @received_messages.empty?
          run_user_app(response)

          if @total_sent_content_length >= max_permitted_content_length
            puts "~ Maximal permitted content length exceeded, closing the connection."

            # Close the response without writing any closing frame.
            self.finish(true)

            @periodic_timer.cancel

            @status = :closed
          else
            puts "~ Permitted content length: #{@total_sent_content_length} of #{max_permitted_content_length}"
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
      @disconnect_timer ||= begin
        EM::Timer.new(@disconnect_delay) do
          puts "~ #{@disconnect_delay} has passed, firing @disconnect_timer"
          @disconnect_timer_canceled = true

          if self.opening? or self.open?
            # OK, so we're here, closing the open response ... but its body is already closed, huh?
            puts "~ @disconnect_timer: closing the connection."
            self.close
            puts "~ @disconnect_timer: connection closed."
          else
            puts "~ @disconnect_timer: doing nothing."
          end
        end
      end
    end

    def reset_timer(&block)
      puts "~ Cancelling @disconnect_timer"
      if @disconnect_timer
        @disconnect_timer.cancel
        @disconnect_timer = nil
      end

      block.call if block

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

    def set_heartbeat_timer(buffer)
      # Cancel @disconnect_timer.
      puts "~ Cancelling @disconnect_timer as we're about to send a heartbeat frame in 25s."
      @disconnect_timer.cancel
      @disconnect_timer = nil

      # Send heartbeat frame after 25s.
      @heartbeat_timer ||= EM::Timer.new(25) do
        # It's better as we know for sure that
        # clearing the buffer won't change it.
        puts "~ Sending heartbeat frame."
        begin
          self.finish
        rescue Exception => error
          # Nah these exceptions are OK ... let's figure out when they occur
          # and let's just not set the timer for such cases in the first place.
          puts "~ Exception when sending heartbeat frame: #{error.inspect}"
        end
      end
    end

    def mark_to_be_garbage_collected
      puts "~ Closing the session"
      @status = :closed
    end
  end


  class WebSocketSession < Session
    attr_accessor :ws
    undef :response

    def send_data(frame)
      if frame.nil?
        raise TypeError.new("Frame must not be nil!")
      end

      unless frame.empty?
        puts "~ @ws.send(#{frame.inspect})"
        @ws.send(frame)
      end
    end

    def finish
      frame = @buffer.to_frame
      self.send_data(frame)
    rescue SockJS::NoContentError => error
      # Why there's no bloody content? That's not right, there should be a closing frame.
      puts "~ finish: no content, setting the heartbeat timer."
      self.set_heartbeat_timer(error.buffer)
    end

    def after_app_run
      return super unless self.closing?

      self.after_close
    end

    def after_close
      puts "~ after_close: calling #finish"
      self.finish

      puts "~ after_close: closing @ws and clearing @transport."
      @ws.close
      @transport = nil
    end
  end


  class SessionWitchCachedMessages < Session
    def send(*messages)
      self.buffer.push(*messages)
    end

    def run_user_app(response)
      puts "~ Executing user's SockJS app"
      frame = self.process_buffer(false)
      # self.send_data(frame) if frame and not frame.match(/^c\[\d+,/)
      puts "~ User's SockJS app finished"
    end

    def send_data(frame)
      super(frame)

      self.close_response
    end

    alias_method :after_app_run, :finish
  end
end
