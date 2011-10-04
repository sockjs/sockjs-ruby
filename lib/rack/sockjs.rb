# encoding: utf-8

require "rack"
require "sockjs"
require "sockjs/adapter"

# Adapters.
require "sockjs/adapters/chunking_test"
require "sockjs/adapters/eventsource"
require "sockjs/adapters/htmlfile"
require "sockjs/adapters/iframe"
require "sockjs/adapters/jsonp"
require "sockjs/adapters/welcome_screen"
require "sockjs/adapters/xhr"

# This is a Rack middleware for SockJS.
#
# @example
#   use SockJS
#   run MyApp
module Rack
  class SockJS
    def initialize(app, prefix = "/echo")
      @app, @prefix = app, prefix
    end

    def call(env)
      matched = env["PATH_INFO"].match(/^#{Regexp.quote(@prefix)}/)

      debug "~ #{env["REQUEST_METHOD"]} #{env["PATH_INFO"].inspect} (matched: #{!! matched})"

      if matched
        ::SockJS.start do |connection|
          prefix  = env["PATH_INFO"].split("/")[2]
          method  = env["REQUEST_METHOD"]
          handler = ::SockJS::Adapter.handler(prefix, method)
          debug "~ Handler: #{handler.inspect}"
          return handler.handle(env).tap do |response|
            debug "~ Response: #{response.inspect}"
            EM.stop
          end
        end
      else
        @app.call(env)
      end
    end

    private
    def debug(message)
      STDERR.puts(message)
    end
  end
end
