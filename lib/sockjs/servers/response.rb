# encoding: utf-8

module SockJS
  # This class is a compatibility layer which makes it possible
  # to work with Rack as well as with other HTTP libraries, Goliath etc.
  # This class is not supposed to be instantiated directly, you have to
  # subclass it and rewrite some library-dependent methods.

  # The API is heavily inspired by Node.js' standard library.
  class Response
    NOT_IMPLEMENTED_PROC ||= Proc.new do |*|
      raise NotImplementedError.new("This is supposed to be rewritten in subclasses!")
    end

    attr_reader :headers
    def initialize(status = nil, headers = Hash.new, body = nil, &block)
      @status, @headers, @body = status, headers, body || String.new

      set_content_length(body) if body && status != 304 || status != 204

      block.call(self) if block
    end

    def set_status(status)
      @status = status
    end

    def set_header(key, value)
      @headers[key] = value
    end

    def set_content_length(body)
      if body && body.respond_to?(:bytesize)
        self.headers["Content-Length"] = body.bytesize.to_s
      end
    end

    def set_session_id(session_id)
      self.headers["Set-Cookie"] = "JSESSIONID=#{session_id}; path=/"
    end

    def write_head(status = nil, headers = nil, &block)
      @status  = status  || @status  || raise("Please set the status!")
      @headers = headers || @headers

      (block || NOT_IMPLEMENTED_PROC).call

      @head_written = true
    end

    def head_written?
      !! @head_written
    end

    def write(&block)
      self.write_head unless self.head_written?

      @last_written_at = Time.now.to_i

      (block || NOT_IMPLEMENTED_PROC).call
    end

    def finish(data = nil, &block)
      if data
        self.write(data)
      else
        self.write_head unless self.head_written?
      end

      (block || NOT_IMPLEMENTED_PROC).call
    end

    def async?
      NOT_IMPLEMENTED_PROC.call
    end

    # Time.now.to_i shows time in seconds.
    def due_for_alive_check
      Time.now.to_i != @last_written_at
    end

    # === Helpers === #
    def set_access_control(origin)
      self.set_header("Access-Control-Allow-Origin", origin)
      self.set_header("Access-Control-Allow-Credentials", "true")
    end

    def set_cache_control
      year = 31536000
      time = Time.now + year

      self.set_header("Cache-Control", "public, max-age=#{year}")
      self.set_header("Expires", time.gmtime.to_s)
      self.set_header("Access-Control-Max-Age", "1000001")
    end

    def set_allow_options_post
      self.set_header("Access-Control-Allow-Methods", "OPTIONS, POST")
    end

    def set_allow_options_get
      self.set_header("Access-Control-Allow-Methods", "OPTIONS, GET")
    end

    def set_no_cache
      self.set_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
    end

    CONTENT_TYPES ||= {
      plain: "text/plain; charset=UTF-8",
      html: "text/html; charset=UTF-8",
      javascript: "application/javascript; charset=UTF-8",
      json: "application/json; charset=UTF-8",
      event_stream: "text/event-stream; charset=UTF-8"
    }

    def set_content_type(symbol)
      if string = CONTENT_TYPES[symbol]
        self.set_header("Content-Type", string)
      else
        raise "No such content type: #{symbol}"
      end
    end

    def set_connection_keep_alive_if_requested
      if @request.env["HTTP_CONNECTION"] && @request.env["HTTP_CONNECTION"].downcase == "keep-alive"
        if @request.http_1_0?
          self.set_header("Connection", "Close")
        else
          # On HTTP/1.1 we should respond with Keep-Alive
          # and Transfer-Encoding: chunked (or with given
          # Content-Length, but due to nature of SockJS,
          # we can't predict the length). However, funny
          # story, Thin doesn't seem to be very happy about
          # it, so let's just say Connection: Close for
          # the time being (as per discussion with @majek).
          self.set_header("Connection", "Close")
        end
      end
    end
  end
end
