# encoding: utf-8

require "thin/request"
require "thin/response"
require "thin/connection"

module Thin
  class Request
    HTTP_1_1 ||= "HTTP/1.1".freeze
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
