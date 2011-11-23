# encoding: utf-8

require "forwardable"

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
    end


    # This is just to make Rack happy.
    # For explanation how does it work check
    # http://macournoyer.com/blog/2009/06/04/pusher-and-async-with-thin
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]


    class Response < Response
      extend Forwardable

      def initialize(request, status = nil, headers = Hash.new, &block)
        @request, @body   = request, DelayedResponseBody.new
        @status, @headers = status, headers

        block.call(self) if block
      end

      def async?
        true
      end

      def write_head(status = nil, headers = nil)
        super(status, headers) do
          callback = @request.env["async.callback"]
          callback.call(@status, @headers, @body)
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
