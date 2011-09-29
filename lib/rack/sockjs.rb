# encoding: utf-8

require "rack"
require "sockjs"

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
      if env["PATH_INFO"].match(/^#@prefix\//)
        ::SockJS.start do |connection|
          prefix  = env["PATH_INFO"].split("/")[2]
          handler = connection.handler(prefix.to_sym)
          handler.handle(env)

          EM.stop
        end
      else
        @app.call(env)
      end
    end
  end
end
