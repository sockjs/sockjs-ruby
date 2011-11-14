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
    def initialize
      @headers, @body = Hash.new, String.new
    end

    def set_status(status)
      @status = status
    end

    def set_header(key, value)
      @headers[key] = value
    end

    def write_head(status = nil, headers = nil, &block)
      @status  = status  || @status  || raise("Please set status!")
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
