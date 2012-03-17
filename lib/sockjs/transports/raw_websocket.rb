# encoding: utf-8

require "sockjs/faye"
require "sockjs/transport"

module SockJS
  module Transports
    class RawWebSocket < Transport
      # Settings.
      self.prefix = /^websocket$/
      self.method = "GET"

      # Handler.
      def handle(request)
      end
    end
  end
end
