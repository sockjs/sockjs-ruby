# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Transports
    class ChunkingTestOptions < Transport
      # Settings.
      self.prefix  = "chunking_test"
      self.method  = "OPTIONS"

      # Handler.
      def handle(request)
        year = 31536000
        time = Time.now + year

        respond(request, 204, set_session_id: true) do |response, session|
          response.set_header("Access-Control-Allow-Origin", request.origin)
          response.set_header("Access-Control-Allow-Credentials", "true")
          response.set_header("Allow", "OPTIONS, POST")
          response.set_header("Cache-Control", "public, max-age=#{year}")
          response.set_header("Expires", time.gmtime.to_s)
          response.set_header("Access-Control-Max-Age", "1000001")

          response.finish
        end
      end
    end

    class ChunkingTestPost < ChunkingTestOptions
      self.method  = "POST"

      # Handler.
      def handle(request)
        respond(request, 200) do |response, session|
          response.set_header("Content-Type", CONTENT_TYPES[:javascript])
          response.set_header("Access-Control-Allow-Origin", request.origin)
          response.set_header("Access-Control-Allow-Credentials", "true")
          response.set_header("Allow", "OPTIONS, POST")
          response.write_head

          timeoutable = SockJS::Timeoutable.new(response.body,
            # IE requires 2KB prelude.
            0    => "h\n",
            1    => " " * 2048 + "h\n",
            5    => "h\n",
            25   => "h\n",
            125  => "h\n",
            625  => "h\n",
            3125 => "h\n",
          )

          response.body.call(timeoutable)
        end
      end
    end
  end
end
