# encoding: utf-8

require "rack"
require "faye/websocket"

require "sockjs"
require "sockjs/transport"
require "sockjs/adapters/servers/thin"

# Transports.
require "sockjs/adapters/transports/chunking_test"
require "sockjs/adapters/transports/eventsource"
require "sockjs/adapters/transports/htmlfile"
require "sockjs/adapters/transports/iframe"
require "sockjs/adapters/transports/jsonp"
require "sockjs/adapters/transports/websocket"
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
        raise "You have to provide SockJS app as a block argument!"
      end

      # Validate options.
      if options[:sockjs_url].nil? && ! options[:disabled_transports].include?(::SockJS::Transports::IFrame)
        raise RuntimeError.new("You have to provide sockjs_url in options, it's required for the iframe transport!")
      end

      @connection ||= begin
        ::SockJS::Connection.new(&block)
      end
    end

    def call(env)
      request = ::SockJS::Thin::Request.new(env)
      matched = request.path_info.match(/^#{Regexp.quote(@prefix)}/)

      matched ? debug_process_request(request) : @app.call(env)
    end

    def debug_process_request(request)
      debug "\n~ \e[31m#{request.http_method} \e[32m#{request.path_info.inspect} \e[0m(\e[34m#{@prefix} app\e[0m)"
      puts "\e[90mcurl -X #{request.http_method} http://localhost:8080#{request.path_info}\e[0m"

      self.process_request(request).tap do |response|
        debug "~ #{response.inspect}"
      end
    end

    def process_request(request)
      prefix   = request.path_info.sub(/^#{Regexp.quote(@prefix)}\/?/, "")
      method   = request.http_method
      handlers = ::SockJS::Transport.handlers(prefix)
      handler  = handlers.find { |handler| handler.method == method }
      if handler
        debug "~ Handler: #{handler_klass.inspect}"
        EM.next_tick do
          handler = handler_klass.new(@connection, @options)
          handler.handle(request)
        end
        ::SockJS::Thin::DUMMY_RESPONSE
      elsif handler.nil? && ! handlers.empty?
        # Unsupported method.
        debug "~ Method not supported!"
        [405, {}, []]
      else
        body = <<-HTML
          <!DOCTYPE html>
          <html>
            <body>
              <h1>Handler Not Found</h1>
              <ul>
                <li>Prefix: #{prefix.inspect}</li>
                <li>Method: #{method.inspect}</li>
                <li>Handlers: #{::SockJS::Transport.subclasses.inspect}</li>
              </ul>
            </body>
          </html>
        HTML
        debug "~ Handler not found!"
        [404, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
      end
    end

    private
    def debug(message)
      STDERR.puts(message)
    end
  end
end
