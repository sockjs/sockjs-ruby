# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    # @deprecated [0.2] As per conversation with Majek.
    class ChunkingTestOptions < Adapter
      # Settings.
      self.prefix  = "chunking_test"
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def self.handle(env, options)
        timeoutable = SockJS::Timeoutable.new(
          # IE requires 2KB prelude.
          0    => " " * 2048 + "h\n",
          5    => "h\n",
          25   => "h\n",
          125  => "h\n",
          625  => "h\n",
          3125 => "h\n",
        )

        [200, {"Content-Type" => "application/javascript; charset=UTF-8"}, timeoutable]
      end
    end

    class ChunkingTestPost < ChunkingTestOptions
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :chunking_test]
    end
  end
end
