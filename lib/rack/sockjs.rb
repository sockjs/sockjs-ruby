# encoding: utf-8

require "rack"
require "sockjs"
require "sockjs/adapter"
require "sockjs/adapters/welcome_screen"

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
      matched = env["PATH_INFO"].match(/^#@prefix\//)

      puts "~ #{env["REQUEST_METHOD"]} #{env["PATH_INFO"].inspect} (matched: #{!! matched})"

      if matched
        ::SockJS.start do |connection|
          prefix  = env["PATH_INFO"].split("/")[2]
          method  = env["REQUEST_METHOD"]
          handler = ::SockJS::Adapter.handler(prefix, method)
          puts "~ Handler: #{handler.inspect}"
          return handler.handle(env).tap do |response|
            puts "~ Response: #{response.inspect}"
            EM.stop
          end
        end
      else
        @app.call(env)
      end
    end
  end
end
