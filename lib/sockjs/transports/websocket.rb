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
        session.buffer = Buffer.new(:open)

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

          # Run the user app.
          session.process_buffer(false)
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing"
      rescue SockJS::InvalidJSON => error
        # @ws.send(error.message) # TODO: frame it ... although ... is it required? The tests do pass, but it would be inconsistent if we'd send it for other transports and not for WS, huh?
        @ws.close # Close the connection abruptly, no closing frame.
      end

      # There are two distinct situations
      # when this handler will be called:
      #
      # 1) User app closes the response.
      #    In this case we need to send
      #    the closing frame and close
      #    the WebSocket connection.
      #
      # 2) Client closes the response
      #    If client closes the response,
      #    there's not much we can do,
      #    only to mark the session
      #    as terminated and delete
      #    it after the 5s timeout.
      def handle_close(request, event)
        puts "~ Closing WS connection."

        # If it's the user app who closed
        # the response, we won't ever get
        # to pass this point as we'll get
        # SessionUnavailableError.
        session = self.get_session(request.path_info)

        if session
          session.close

          # Send the closing frame.
          frame = session.process_buffer || 'c[3000,"Go away!"]'# FIXME: This is a hack for the time being. Where's the bloody "c" frame?
          session.send_data(frame)
          session.after_close
        else
          puts "~ Session can't be retrieved, something went pretty damn wrong."

          session.send_data('c[3000,"Go away!"]') # ONLY a temporary fallback for the time being!
        end
      rescue SockJS::SessionUnavailableError
        puts "~ Session is already closing, handle_close won't be called."
      end
    end
  end
end
