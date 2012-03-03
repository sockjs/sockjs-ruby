# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports

    class Info < Transport
      # Settings.
      self.prefix = /\/info$/
      self.method = "GET"

      # Handler.
      def handle(request)
        # TODO: Continue here ...
      end
    end
  end
end
