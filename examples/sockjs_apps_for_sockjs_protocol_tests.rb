#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
require "bundler/setup"

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rack"
require "thin"
require "eventmachine"

$DEBUG = true

def next_argument(argument)
  if ARGV.include?(argument)
    ARGV[ARGV.index(argument) + 1]
  end
end

PORT = next_argument("-p") || 8081

::Thin::Connection.class_eval do
  def handle_error(error = $!)
    log "[#{error.class}] #{error.message}\n  - "
    log error.backtrace.join("\n  - ")
    close_connection rescue nil
  end
end

# Let's make Lint to STFU. See
# XHRSendPost#handle for an explanation.
class Rack::Lint
  def call(env)
    @app.call(env)
  end
end

require "rack/sockjs"
require "json"

SockJS.debug!

class MyHelloWorld
  def call(env)
    body = <<-HTML
<html>
  <head>
    <title>Hello World!</title>
  </head>

  <body>
    <h1>Hello World!</h1>
    <p>
      This is the app, not SockJS.
    </p>
  </body>
</html>
    HTML
    [200, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
  end
end

SockJS.debug "Available handlers: #{::SockJS::Transport.subclasses.inspect}"

options = {sockjs_url: "http://cdn.sockjs.org/sockjs-#{SockJS::PROTOCOL_VERSION}.min.js"}

app = Rack::Builder.new do
  use Rack::SockJS, "/echo", options do |connection|
    connection.subscribe do |session, message|
      SockJS.debug "\033[0;31;40m[Echo]\033[0m message: #{message.inspect}, session: #{session.object_id}"
      session.send(message)
    end
  end

  use Rack::SockJS, "/disabled_websocket_echo", options.merge(websocket: false) do |connection|
    connection.subscribe do |session, message|
      SockJS.debug "\033[0;31;40m[Echo]\033[0m message: #{message.inspect}, session: #{session.object_id}"
      session.send(message)
    end
  end

  use Rack::SockJS, "/close", options do |connection|
    # With WebSockets this occurs immediately, so the
    # client receives "o" and then "c[3000, "Go away!"]".
    # However with polling, this will occur with the next request.
    connection.session_open do |session, message|
      SockJS.debug "\033[0;31;40m[Close]\033[0m closing the session ..."
      session.close(3000, "Go away!")
    end
  end

  run MyHelloWorld.new
end

EM.run do
  thin = Rack::Handler.get("thin")
  thin.run(app.to_app, Port: PORT)
end
