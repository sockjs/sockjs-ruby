# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class WebSocket < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/websocket$/
      self.method  = "GET"

      def invalid_request_or_disabled_websocket?(request)
        if self.disabled?
          status, body = 404, "WebSockets Are Disabled"
        elsif request.env["HTTP_UPGRADE"] != "WebSocket"
          status, body = 400, 'Can "Upgrade" only to "WebSocket".'
        elsif request.env["HTTP_CONNECTION"] != "Upgrade"
          status, body = 400, '"Connection" must be "Upgrade".'
        else
          return false
        end

        self.write_response(request, status, Hash.new, body)
      end

      # Handlers.
      def handle(request)
        unless invalid_request_or_disabled_websocket?(request)
          puts "~ Upgrading to WebSockets ..."

          ws = Faye::WebSocket.new(request.env)

          def ws.send(msg); super msg; puts " WS#send ~ #{msg.inspect}"; end

          # Whops, this is obviously wrong ...
          handler = ::SockJS::Adapters::WebSocket.new(@connection, @options)
          handler.handle_open(request, ws)

          ws.onmessage = lambda do |event|
            debug "~ WS data received: #{event.data.inspect}"
            handler.handle_message(request, event, ws)
          end

          ws.onclose = lambda do |event|
            debug "~ Closing WebSocket connection (#{event.code}, #{event.reason})"
            handler.handle_close(request, ws)
          end

          # Thin async response
          ::SockJS::Thin::DUMMY_RESPONSE
        end
      end

      def handle_open(request, ws)
        puts "~ Opening WS connection."
        match = request.path_info.match(self.class.prefix)
        session = self.connection.create_session(match[1], self)
        session.open!
        session.check_status

        messages = session.process_buffer.chomp
        ws.send(messages.chomp) unless messages == "a[]"
        # OK, this is a huge mess! Let's rework sessions,
        # so session#send can work instantly without this
        # senseless crap ... because obviously in case
        # of websockets, we don't need to buffer
        # the messages and wait for sending the response.
      end

      def format_frame(payload)
        payload
      end

      def handle_close(request, ws)
        puts "~ Closing WS connection."
        match = request.path_info.match(self.class.prefix)
        session = self.connection.sessions[match[1]]
        session.close

        messages = session.process_buffer.chomp
        ws.send(messages)
      end

      def handle_message(request, event, ws)
        puts "~ WS message received: #{event.data.inspect}"
        match = request.path_info.match(self.class.prefix)
        session = self.connection.sessions[match[1]]
        session.receive_message(event.data)
        messages = session.process_buffer.chomp
        p [:mess, messages]
        ws.send(messages)
      rescue SockJS::InvalidJSON
        session.close
      end
    end
  end
end
