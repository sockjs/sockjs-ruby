# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class ChunkingTestOptions < Adapter
      # Settings.
      self.prefix  = "chunking_test"
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end

    class ChunkingTestPost < ChunkingTestOptions
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :chunking_test]
    end
  end
end
