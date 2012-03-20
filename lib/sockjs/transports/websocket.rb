# encoding: utf-8

require_relative "./raw_websocket"

module SockJS
  module Transports
    class WebSocket < RawWebSocket
      extend Forwardable

      # Settings.
      self.prefix = /[^.]+\/([^.]+)\/websocket$/
      self.method = "GET"

      # Handlers.
      def handle_open(request)
        puts "~ Opening WS connection."
        match = request.path_info.match(self.class.prefix)
        session = self.create_session(request.path_info)
        session.ws = @ws
        session.buffer = Buffer.new # This is a hack for the bloody API. Rethinking and refactoring required!
        session.transport = self

        # Send the opening frame.
        session.open!
        session.check_status
        session.buffer = RawBuffer.new(:open)

        session.process_buffer # Run the app (connection.session_open hook).
      end

      def handle_message(request, event)
        message = event.data

        # Unlike other transports, the WS one is supposed to ignore empty messages.
        unless message.empty?
          message = "[#{message}]" unless message.start_with?("[")
          puts "<~ WS message received: #{message.inspect}"
          session = self.get_session(request.path_info)
          session.receive_message(request, message)

          # Send encoded messages in an array frame.
          messages = session.process_buffer
          if messages.start_with?("a[") # a[] frames are sent immediatelly! FIXME!
            puts "~ Messages to be sent: #{messages.inspect}"
            @ws.send(messages)
          end
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing"
      rescue SockJS::InvalidJSON => error
        # @ws.send(error.message) # TODO: frame it ... although ... is it required? The tests do pass, but it would be inconsistent if we'd send it for other transports and not for WS, huh?
        @ws.close # Close the connection abruptly, no closing frame.
      end

      def handle_close(request, event)
        puts "~ Closing WS connection."
        session = self.get_session(request.path_info)

        if session
          session.close

          # Send the closing frame.
          @ws.send(session.process_buffer)

          session.transport = nil
        else
          puts "~ Session can't be retrieved, something went pretty damn wrong."

          @ws.send('c[3000,"Go away!"]') # ONLY a temporary fallback for the time being!
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing"
      end
    end
  end
end
