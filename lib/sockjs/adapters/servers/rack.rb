# encoding: utf-8

require "sockjs/response"

module SockJS
  class RackResponse < Response
    def write_head(status = nil, headers = nil)
      @status  = status  || @status
      @headers = headers || @headers
    end

    def write(data)
      @body << data
    end

    def finish(data = nil)
      self.write(data) if data

      [@status, @headers, [@body]]
    end
  end
end
