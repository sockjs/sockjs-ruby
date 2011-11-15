# encoding: utf-8

require "uri"

module SockJS
  # This class is a compatibility layer which makes it possible
  # to work with Rack as well as with other HTTP libraries, Goliath etc.
  # This class is not supposed to be instantiated directly, you have to
  # subclass it and rewrite some library-dependent methods.

  # The API is heavily inspired by Node.js' standard library.
  class Request
    # request.http_method
    # => "GET"
    def http_method
      raise NotImplementedError.new("You are supposed to rewrite #http_method in a subclass!")
    end

    # request.path_info
    # => /echo/abc
    def path_info
      raise NotImplementedError.new("You are supposed to rewrite #path_info in a subclass!")
    end

    # request.headers["origin"]
    # => http://foo.bar
    def headers
      raise NotImplementedError.new("You are supposed to rewrite #headers in a subclass!")
    end

    def origin
      self.headers["origin"] || "*"
    end

    def content_type
      self.headers["content-type"]
    end

    # request.query_string["callback"]
    # => "myFn"
    def query_string
      raise NotImplementedError.new("You are supposed to rewrite #query_string in a subclass!")
    end

    def callback
      callback = self.query_string["callback"] || self.query_string["c"]
      URI.unescape(callback) if callback
    end

    # request.cookies["JSESSIONID"]
    # => "123sd"
    def cookies
      raise NotImplementedError.new("You are supposed to rewrite #cookies in a subclass!")
    end

    def session_id
      self.cookies["JSESSIONID"]
    end

    # request.data.read
    # => "message"
    def data
      raise NotImplementedError.new("You are supposed to rewrite #data in a subclass!")
    end
  end
end
