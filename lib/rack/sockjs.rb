# encoding: utf-8

require "rack"
require "sockjs"
require "sockjs/adapter"
require "sockjs/adapters/servers/rack"

# Adapters.
require "sockjs/adapters/transports/chunking_test"
require "sockjs/adapters/transports/eventsource"
require "sockjs/adapters/transports/htmlfile"
require "sockjs/adapters/transports/iframe"
require "sockjs/adapters/transports/jsonp"
require "sockjs/adapters/transports/welcome_screen"
require "sockjs/adapters/transports/xhr"

# This is a Rack middleware for SockJS.
#
# @example
#  require "rack/sockjs"
#
#  use SockJS, "/echo" do |connection|
#    connection.subscribe do |session, message|
#      session.send(message)
#    end
#  end
#
#  use SockJS, "/disabled_websocket_echo",
#    disabled_transports: [SockJS::WebSocket] do |connection|
#    # ...
#  end
#
#  use SockJS, "/close" do |connection|
#    connection.session_open do |session|
#      session.close(3000, "Go away!")
#    end
#  end
#
#  run MyApp

module Rack
  class SockJS
    def initialize(app, prefix = "/echo", options = Hash.new, &block)
      @app, @prefix, @options = app, prefix, options

      unless block
        raise "You have to provide SockJS app as the block argument!"
      end

      # Validate options.
      if options[:sockjs_url].nil? && ! options[:disabled_transports].include?(::SockJS::Adapters::IFrame)
        raise RuntimeError.new("You have to provide sockjs_url in options, it's required for the iframe transport!")
      end

      @connection ||= begin
        ::SockJS::Connection.new(&block)
      end
    end

    def call(env)
      request = ::SockJS::Rack::Request.new(env)
      matched = request.path_info.match(/^#{Regexp.quote(@prefix)}/)

      debug "~ #{request.http_method} #{request.path_info.inspect} (matched: #{!! matched})"

      if matched
        prefix        = request.path_info.sub(/^#{Regexp.quote(@prefix)}\/?/, "")
        method        = request.http_method
        handler_klass = ::SockJS::Adapter.handler(prefix, method)
        if handler_klass
          debug "~ Handler: #{handler_klass.inspect}"
          handler = handler_klass.new(@connection, @options)
          return handler.handle(request).tap do |response|
            debug "~ Response: #{response.inspect}"
          end
        else
          body = <<-HTML
            <!DOCTYPE html>
            <html>
              <body>
                <h1>Handler Not Found</h1>
                <ul>
                  <li>Prefix: #{prefix.inspect}</li>
                  <li>Method: #{method.inspect}</li>
                  <li>Handlers: #{::SockJS::Adapter.subclasses.inspect}</li>
                </ul>
              </body>
            </html>
          HTML
          [404, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
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
