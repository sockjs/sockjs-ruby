#!/usr/bin/env rackup -s thin -p 8080
# encoding: utf-8

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "thin"

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

def debug(message)
  STDERR.puts(message)
end

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

puts "~ Available handlers: #{::SockJS::Adapter.subclasses.inspect}"

options = {sockjs_url: "http://cdn.sockjs.org/sockjs-0.1.min.js"}

use Rack::SockJS, "/echo", options do |connection|
  connection.subscribe do |session, message|
    debug "~ \033[0;31;40m[Echo]\033[0m message: #{message.inspect}, session: #{session.inspect}"
    session.send(message)
  end
end

use Rack::SockJS, "/close", options do |connection|
  # With WebSockets this occurs immediately, so the
  # client receives "o" and then "c[3000, "Go away!"]".
  # However with polling, this will occur with the next request.
  connection.session_open do |session, message|
    debug "~ \033[0;31;40m[Close]\033[0m closing the session ..."
    session.close(3000, "Go away!")
  end
end

run MyHelloWorld.new
