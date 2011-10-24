# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class WelcomeScreen < Adapter
      # Settings.
      self.prefix = ""
      self.method = "GET"

      # Handler.
      def handle(env, &block)
        body = "Welcome to SockJS!\n"
        [200, {"Content-Type" => "text/plain; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
      end
    end
  end
end
