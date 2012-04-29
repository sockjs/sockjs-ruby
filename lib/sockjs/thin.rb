# encoding: utf-8

require "thin/request"
require "thin/response"
require "thin/connection"

module Thin
  class Request
    HTTP_1_1 ||= "HTTP/1.1".freeze

    # https://github.com/macournoyer/thin/blob/master/lib/thin/request.rb#L109-122
    def persistent?
      SockJS.debug "Determining request persistency:"

      # Clients and servers SHOULD NOT assume that a persistent connection
      # is maintained for HTTP versions less than 1.1 unless it is explicitly
      # signaled. (http://www.w3.org/Protocols/rfc2616/rfc2616-sec8.html)
      if @env[HTTP_VERSION] == HTTP_1_0
        condition = @env[CONNECTION] =~ KEEP_ALIVE_REGEXP
        SockJS.debug "Using HTTP/1.0. Keep-Alive: #{!! condition}"
        return condition

      # HTTP/1.1 client intends to maintain a persistent connection unless
      # a Connection header including the connection-token "close" was sent
      # in the request
      else
        condition = @env[CONNECTION].nil? || @env[CONNECTION] !~ CLOSE_REGEXP
        SockJS.debug "Using HTTP/1.1. Keep-Alive: #{condition}"
        return condition
      end
    end
  end

  class Response
    attr_writer :http_version
    def http_version
      @http_version || ::Thin::Request::HTTP_1_1
    end

    def head
      "#{self.http_version} #{@status} #{HTTP_STATUS_CODES[@status.to_i]}\r\n#{headers_output}\r\n"
    end
  end

  class Connection
    alias_method :_process, :process

    # Called when all data was received and the request
    # is ready to be processed.
    def process
      @response.http_version = @request.env[Thin::Request::HTTP_VERSION]
      _process
    end
  end
end
