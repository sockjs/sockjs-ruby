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

      (block || NOT_IMPLEMENTED_PROC).call
    end

    def finish(data = nil, &block)
      self.write(data) if data

      (block || NOT_IMPLEMENTED_PROC).call
    end
  end
end
