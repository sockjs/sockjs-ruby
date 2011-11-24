# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class WelcomeScreen < Adapter
      # Settings.
      self.prefix = ""
      self.method = "GET"

      # Handler.
      def handle(request)
        self.write_response(request, 200,
          {"Content-Type" => CONTENT_TYPES[:plain]},
          "Welcome to SockJS!\n")
      end
    end
  end
end
