# encoding: utf-8

require "forwardable"
require "sockjs/thin"

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
        # request.env["async.close"]
        # ["rack.input"].closed? # it's a stream
        @request, @status, @headers = request, status, headers

        if request.env["HTTP_VERSION"] == "HTTP/1.0"
          @body = DelayedResponseBody.new
        else
          @body = DelayedResponseChunkedBody.new
        end

        puts "~ HTTP_VERSION is #{request.env["HTTP_VERSION"].inspect}, using body #{@body}."

        block.call(self) if block

        set_connection_keep_alive_if_requested
      end

      def session=(session)
        @body.session = session
      end

      def async?
        true
      end

      def write_head(status = nil, headers = nil)
        super(status, headers) do
          if @headers["Content-Length"]
            raise "You can't use Content-Length with chunking!"
          end

          unless @request.http_1_0? || @status == 204
            turn_chunking_on(@headers)
          end

          callback = @request.env["async.callback"]

          puts "~ Headers: #{@headers.inspect}"

          callback.call([@status, @headers, @body])
        end
      end

      def turn_chunking_on(headers)
        headers["Transfer-Encoding"] = "chunked"
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

      attr_accessor :session

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
          raise "Body isn't open (status: #{@status}, trying to write #{chunk.inspect})"
        end

        unless chunk.respond_to?(:bytesize)
          raise "Chunk is supposed to respond to #bytesize, but it doesn't.\nChunk: #{chunk.inspect} (#{chunk.class})"
        end

        puts "~ body#write #{chunk.inspect}"

        self.write_chunk(chunk)
      end

      def each(&block)
        puts "~ Opening the response."
        @status = :open
        @body_callback = block
      end

      def succeed(from_server = true)
        if $DEBUG
          puts "~ Closing the response #{caller[5..-8].map { |item| item.sub(Dir.pwd + "/lib/", "") }.inspect}."
        else
          puts "~ Closing the response."
        end

        @status = :closed
        super
      end

      def finish(data = nil)
        if @status == :closed
          raise "Body is already closed!"
        end

        self.write(data) if data

        self.succeed(true)
      end

      def closed?
        @status == :closed
      end

      protected
      def write_chunk(chunk)
        self.__write__(chunk)
      end

      def __write__(data)
        @body_callback.call(data)
      end
    end


    # https://github.com/rack/rack/blob/master/lib/rack/chunked.rb
    class DelayedResponseChunkedBody < DelayedResponseBody
      TERM ||= "\r\n"
      TAIL ||= "0#{TERM}#{TERM}"

      def finish(data = nil)
        if @status == :closed
          raise "Body is already closed!"
        end

        self.write(data) if data
        self.__write__(TAIL)

        self.succeed(true)
      end

      protected
      def write_chunk(chunk)
        data = [chunk.bytesize.to_s(16), TERM, chunk, TERM].join
        self.__write__(data)
      end
    end
  end
end
