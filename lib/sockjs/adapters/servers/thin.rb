# encoding: utf-8

require "forwardable"

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
    end


    # This is just to make Rack happy.
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]


    class Response < Response
      def async?
        @body.is_a?(DelayedResponseBody)
      end
    end


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


    class DelayedResponseBody
      include EventMachine::Deferrable

      def call(body)
        body.each do |chunk|
          self.write(chunk)
        end
      end

      def write(chunk)
        @body_callback.call(chunk)
      end

      def each(&block)
        @body_callback = block
      end

      alias_method :finish, :succeed
    end
  end
end
