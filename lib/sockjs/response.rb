# encoding: utf-8

module SockJS
  # This class is a compatibility layer which makes it possible
  # to work with Rack as well as with other HTTP libraries, Goliath etc.
  # This class is not supposed to be instantiated directly, you have to
  # subclass it and rewrite some library-dependent methods.

  # The API is heavily inspired by Node.js' standard library.
  class Response
    attr_reader :headers
    def initialize
      @headers, @body = Hash.new, String.new
    end

    def set_status(status)
      @status = status
    end

    def set_header(key, value)
      @headers[key] = value
    end

    def write_head(status = nil, headers = nil)
      @status  = status  || @status
      @headers = headers || @headers

      raise NotImplementedError.new("This is supposed to be rewritten in subclasses!")
    end

    def write(data)
      raise NotImplementedError.new("This is supposed to be rewritten in subclasses!")
    end

    def finish(data = nil)
      self.write(data) if data

      raise NotImplementedError.new("This is supposed to be rewritten in subclasses!")
    end
  end
end
