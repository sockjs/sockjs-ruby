# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class ChunkingTestOptions < Adapter
      # Settings.
      self.prefix  = "chunking_test"
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(request)
        year = 31536000
        time = Time.now + year

        headers = {"Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true", "Allow" => "OPTIONS, POST", "Cache-Control" => "public, max-age=#{year}", "Expires" => time.gmtime.to_s, "Access-Control-Max-Age" => "1000001"}

        self.write_response(request, 204, headers, "") do |response|
          response.set_session_id(request.session_id)
        end
      end
    end

    class ChunkingTestPost < ChunkingTestOptions
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :chunking_test]

      # Handler.
      def handle(request)
        headers = {"Content-Type" => CONTENT_TYPES[:javascript], "Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Credentials" => "true", "Allow" => "OPTIONS, POST"}

        response = self.response(request, 200, headers)
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
