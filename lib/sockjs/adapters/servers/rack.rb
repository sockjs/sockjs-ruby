# encoding: utf-8

require "sockjs/response"

module SockJS
  class RackResponse < Response
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
        [@status, @headers, [@body]]
      end
    end
  end
end
