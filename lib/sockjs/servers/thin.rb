# encoding: utf-8

require "forwardable"

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
      # We need to access the async.callback.
      attr_reader :env
    end


    # This is just to make Rack happy.
    # For explanation how does it work check
    # http://macournoyer.com/blog/2009/06/04/pusher-and-async-with-thin
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]


    class Response < Response
      extend Forwardable

      attr_reader :status, :headers, :body
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
          if @headers["Content-Length"]
            raise "You can't use Content-Length with chunking!"
          end

          unless @status == 204
            @headers["Transfer-Encoding"] = "chunked"
          end

          callback = @request.env["async.callback"]

          puts "~ Headers: #{@headers.inspect}"

          callback.call([@status, @headers, @body])
        end
      end

      def write(data)
        super() do
          @body.write(data)
        end
      end

      def finish(data = nil)
        super(data) do
          @body.finish
        end
      end

      # Delegators don't care about writing head etc.
      # def_delegator :body, :write
      # def_delegator :body, :finish
    end


    class DelayedResponseBody
      include EventMachine::Deferrable

      TERM ||= "\r\n"
      TAIL ||= "0#{TERM}#{TERM}"

      def initialize
        @status = :created
        super # TODO: Is this necessary?
      end

      def call(body)
        body.each do |chunk|
          self.write(chunk)
        end
      end

      def write(chunk)
        unless @status == :open
          raise "Body isn't open (status: #{@status})"
        end

        unless chunk.respond_to?(:bytesize)
          raise "Chunk is supposed to respond to #bytesize, but it doesn't.\nChunk: #{chunk.inspect} (#{chunk.class})"
        end

        STDERR.puts("~ body#write #{chunk.inspect}")
        data = [chunk.bytesize.to_s(16), TERM, chunk, TERM].join
        self.__write__(data)
      end

      def each(&block)
        STDERR.puts("~ Opening the response.")
        @status = :open
        @body_callback = block
      end

      def succeed
        if $DEBUG
          STDERR.puts("~ Closing the response #{caller.map { |item| item.sub(Dir.pwd + "/lib/", "") }.inspect}.")
        else
          STDERR.puts("~ Closing the response.")
        end

        self.__write__(TAIL)
        @status = :closed
        super
      end

      def finish(data = nil)
        if @status == :closed
          raise "Body is already closed!"
        end

        self.write(data) if data
        self.succeed
      end

      protected
      def __write__(data)
        @body_callback.call(data)
      end
    end
  end
end
