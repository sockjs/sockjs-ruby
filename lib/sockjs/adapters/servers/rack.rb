# encoding: utf-8

require "sockjs/request"
require "sockjs/response"

module SockJS
  module Rack
    class Request < Request
      def initialize(env)
        @env = env
      end

      # request.http_method
      # => "GET"
      def http_method
        @env["REQUEST_METHOD"]
      end

      # request.path_info
      # => /echo/abc
      def path_info
        @env["PATH_INFO"]
      end

      # request.headers["origin"]
      # => http://foo.bar
      def headers
        @headers ||= begin
          permitted_keys = /^(CONTENT_(LENGTH|TYPE))$/

          @env.reduce(Hash.new) do |headers, (key, value)|
            if key.match(/^HTTP_(.+)$/) || key.match(permitted_keys)
              headers[$1.downcase.tr("_", "-")] = value
            end

            headers
          end
        end
      end

      # request.query_string["callback"]
      # => "myFn"
      def query_string
        @query_string ||= begin
          @env["QUERY_STRING"].split("=").each_slice(2).reduce(Hash.new) do |buffer, pair|
            buffer.merge(pair.first => pair.last)
          end
        end
      end

      # request.cookies["JSESSIONID"]
      # => "123sd"
      def cookies
        @cookies ||= begin
          ::Rack::Request.new(@env).cookies
        end
      end

      # request.data.read
      # => "message"
      def data
        @env["rack.input"]
      end
    end

    class Response < Response
      def write_head(status = nil, headers = nil)
        super(status, headers) do
          # The actual implementation.
        end
      end

      def write(data)
        super() do
          @body << data
        end
      end

      def finish(data = nil)
        super(data) do
          @body = [@body] if @body.respond_to?(:bytesize)
          [@status, @headers, @body]
        end
      end
    end

    class DelayedResponseBody
      # Implementation: fibers? EM?

      # response.write("data")
      def each(&block)
        # wait until finish
        # block.call(data) if block
      end

      # this refactoring means we'll return [200, {}, []] in first write, not finish!

      def finish
        # done
      end
    end
  end
end
