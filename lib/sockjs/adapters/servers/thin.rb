# encoding: utf-8

require "forwardable"

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
    end


    # This is just to make Rack happy.
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]


    class AsyncResponse < Response
      extend Forwardable

      # env["async.callback"]
      def initialize(async_callback, status = nil, headers = Hash.new, &block)
        @async_callback   = async_callback
        @status, @headers = status, headers
        @body = DelayedResponseBody.new

        block.call(self) if block
      end

      def write_head(status = nil, headers = nil)
        super(status, headers) do
          @async_callback.call(@status, @headers, @body)
        end
      end

      def_delegator :body, :write
      def_delegator :body, :finish
    end
  end
end
