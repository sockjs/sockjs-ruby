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

  class RackDelayedResponseBody
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
