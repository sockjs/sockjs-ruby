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
        p [:ws_open]
        ws.send("o")
      end

      def handle_close(request, ws)
        p [:ws_close]
        ws.send("c")
      end

      def handle_message(request, event, ws)
        p [:ws_message, event.data]
      end
    end
  end
end
