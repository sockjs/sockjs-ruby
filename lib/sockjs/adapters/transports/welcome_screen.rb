# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class WelcomeScreen < Adapter
      # Settings.
      self.prefix = ""
      self.method = "GET"

      # Handler.
      def handle(env)
        self.write_response(200,
          {"Content-Type" => "text/plain; charset=UTF-8"},
          "Welcome to SockJS!\n")
      end
    end
  end
end
