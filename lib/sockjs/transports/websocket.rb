# encoding: utf-8

require "faye/websocket"
require "forwardable"
require "sockjs/transport"

module SockJS
  module Transports
    class WebSocket < Transport
      extend Forwardable

      # Settings.
      self.prefix = /[^.]+\/([^.]+)\/websocket$/
      self.method = "GET"

      def session_class
        SockJS::Session
      end

      def_delegator :@ws, :send

      def check_invalid_request_or_disabled_websocket(request)
        if self.disabled?
          raise HttpError.new(404, "WebSockets Are Disabled")
        elsif request.env["HTTP_UPGRADE"] != "WebSocket"
          raise HttpError.new(400, 'Can "Upgrade" only to "WebSocket".')
        elsif request.env["HTTP_CONNECTION"] != "Upgrade"
          raise HttpError.new(400, '"Connection" must be "Upgrade".')
        end
      end

      # Handlers.
      def handle(request)
        check_invalid_request_or_disabled_websocket(request)

        puts "~ Upgrading to WebSockets ..."

        @ws = Faye::WebSocket.new(request.env)

        def @ws.send(msg); puts " WS#send ~ #{msg.inspect}"; super msg; end

        self.handle_open(request)

        @ws.onmessage = lambda do |event|
          debug "~ WS data received: #{event.data.inspect}"
          self.handle_message(request, event)
        end

        @ws.onclose = lambda do |event|
          debug "~ Closing WebSocket connection (#{event.code}, #{event.reason})"
          self.handle_close(request, event)
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end

      def handle_open(request)
        puts "~ Opening WS connection."
        match = request.path_info.match(self.class.prefix)
        session = self.create_session(request.path_info)
        session.open!
        session.check_status

        # Send the opening frame.
        self.send(session.process_buffer)
      end

      def handle_message(request, event)
        puts "~ WS message received: #{event.data.inspect}"
        session = self.get_session(request.path_info)
        session.receive_message(event.data)

        # Send encoded messages in an array frame.
        self.send(session.process_buffer)
      rescue SockJS::InvalidJSON
        session.close
      end

      def handle_close(request, event)
        puts "~ Closing WS connection."
        session = self.get_session(request.path_info)
        session.close

        # Send the closing frame.
        self.send(session.process_buffer)
      end

      def format_frame(payload)
        raise TypeError.new if payload.nil?

        payload
      end

      # In this adapter we send everything straight away,
      # hence there's no need for #finish. See session.rb.
      def session_finish
      end
    end
  end
end
