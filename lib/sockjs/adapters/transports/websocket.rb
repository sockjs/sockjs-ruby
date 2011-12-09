# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class WebSocket < Adapter
      # Handlers.
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
