# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports

    class Info < Transport
      # Settings.
      self.prefix = "info"
      self.method = "GET"

      # Handler.
      def handle(request)
        response(request, 200) do |response|
          response.set_content_type(:json)
          response.set_access_control(request.origin)
          response.set_allow_options_post
          response.set_no_cache
          response.write(self.info.to_json)
        end
      end

      def info
        {
          # websocket: "@options.websocket",
          # origins: "@options.origins",
          # cookie_needed: "not not @options.jsessionid",
          entropy: self.entropy
        }
      end

      def entropy
        foo = -> { (rand * 256).round }
        v = [foo.(), foo.(), foo.(), foo.()]
        return v[0] + (v[1] * 256 ) + (v[2] * 256 * 256) + (v[3] * 256 * 256 * 256)
      end
    end
  end
end
