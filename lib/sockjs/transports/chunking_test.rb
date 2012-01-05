# encoding: utf-8

require "sockjs/transport"
require "sockjs/utils"

module SockJS
  module Transports
    class ChunkingTestOptions < Transport
      # Settings.
      self.prefix = "chunking_test"
      self.method = "OPTIONS"

      # Handler.
      def handle(request)
        respond(request, 204) do |response|
          response.set_session_id(request.session_id)
          response.set_access_control(request.origin)
          response.set_allow_options_post
          response.set_cache_control
        end
      end
    end

    class ChunkingTestPost < ChunkingTestOptions
      self.method = "POST"

      # Handler.
      def handle(request)
        response(request, 200) do |response|
          response.set_content_type(:javascript)
          response.set_access_control(request.origin)
          response.set_allow_options_post

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
