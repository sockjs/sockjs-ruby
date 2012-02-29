# encoding: utf-8

require "faye/websocket"
require "forwardable"
require "sockjs/transport"

module SockJS
  module Transports
    module WSDebuggingMixin
      def send(msg)
        if $DEBUG
          puts "~> WS#send #{msg.inspect} #{caller[0..2].map { |item| item.sub(Dir.pwd + "/lib/", "") }.inspect}"
        else
          puts "~> WS#send #{msg.inspect}"
        end
        super msg
      end
    end

    class WebSocket < Transport
      extend Forwardable

      # Settings.
      self.prefix = /[^.]+\/([^.]+)\/websocket$/
      self.method = "GET"

      def session_class
        SockJS::Session
      end

      def send(_, frame)
        @ws.send(frame)
      end

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

        @ws.extend(WSDebuggingMixin)

        self.handle_open(request)

        @ws.onmessage = lambda do |event|
          debug "<~ WS data received: #{event.data.inspect}"
          self.handle_message(request, event)
        end

        @ws.onclose = lambda do |event|
          debug "~ Closing WebSocket connection (code: #{event.code}, reason: #{event.reason.inspect})"
          self.handle_close(request, event)
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end

      def handle_open(request)
        puts "~ Opening WS connection."
        match = request.path_info.match(self.class.prefix)
        session = self.create_session(request.path_info)
        session.buffer = Buffer.new # This is a hack for the bloody API. Rethinking and refactoring required!

        # Send the opening frame.
        session.open!

        session.process_buffer # Run the app (connection.session_open hook).
      end

      def handle_message(request, event)
        puts "<~ WS message received: #{event.data.inspect}"
        session = self.get_session(request.path_info)
        session.receive_message(event.data)

        # Send encoded messages in an array frame.
        messages = session.process_buffer
        if messages.start_with?("a[") # a[] frames are sent immediatelly! FIXME!
          puts "~ Messages to be sent: #{messages.inspect}"
          @ws.send(messages)
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing"
      rescue SockJS::InvalidJSON
        @ws.close # Close the connection abruptly, no closing frame.
      end

      def handle_close(request, event)
        puts "~ Closing WS connection."
        session = self.get_session(request.path_info)

        if session
          session.close

          # Send the closing frame.
          @ws.send(session.process_buffer)
        else
          puts "~ Session can't be retrieved, something went pretty damn wrong."

          @ws.send('c[3000,"Go away!"]') # ONLY a temporary fallback for the time being!
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing"
      end

      def format_frame(payload)
        raise TypeError.new if payload.nil?

        payload
      end

      # TODO: Rename to request_finish or something like that.
      def session_finish(frame)
        @ws.send(frame)
      end
    end
  end
end
