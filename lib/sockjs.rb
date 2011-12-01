# encoding: utf-8

require "eventmachine"
require "sockjs/utils"
require "sockjs/protocol"
require "sockjs/version"

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

  class HttpError < StandardError
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def to_response(adapter, request)
      adapter.write_response(request, 500, {"Content-Type" => "text/plain"}, self.message)
    end
  end

  class InvalidJSON < HttpError
    def initialize(*)
      @message = "Broken JSON encoding."
    end
  end

  class EmptyPayload < HttpError
    def initialize(*)
      @message = "Payload expected."
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
      if @sessions
        @sessions.delete_if do |_, session|
          session.closed?
        end
      else
        @sessions = Hash.new
      end
    end

    def subscribe(&block)
      self.callbacks[:subscribe] << block
    end

    def session_open(&block)
      self.callbacks[:session_open] << block
    end

    def create_session(key)
      self.sessions[key] ||= begin
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
      @disconnect_delay = 5 # TODO: make this configurable.
      @status = :created
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

      @received_messages.push(*parse_json(data))
    end

    def parse_json(data)
      raise EmptyPayload.new if data == "[]"
      JSON.parse(data)
    rescue JSON::ParserError => error
      raise SockJS::InvalidJSON.new(error.message)
    end

    def open!
      self.status = :opening
      self.set_timer

      Protocol::OPEN_FRAME
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

        @messages_for_the_client
      end
    end

    def close(status = 3000, message = "Go away!")
      @status = :closing
      @error = SockJS::CloseError.new(status, message)

      # raise @error # NOPE!

      @close_timer = EM::Timer.new(@disconnect_delay) do
        self.mark_to_be_garbage_collected
      end
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

    def closed?
      @status == :close
    end

    protected
    def set_timer
      @disconnect_timer = begin
        EM::Timer.new(@disconnect_delay) do
          puts "~ Closing the connection."
          self.close
        end
      end
    end

    def reset_timer
      @disconnect_timer.cancel
      self.set_timer
    end

    def mark_to_be_garbage_collected
      @status = :close
    end

    def check_status
      if @status == :opening
        @status = :open
        self.execute_callback(:open, self)
      end
    end
  end
end
