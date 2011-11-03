#!/usr/bin/env rackup -s thin -p 8080
# encoding: utf-8

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

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

options = {sockjs_url: "http://sockjs.github.com/sockjs-client/sockjs-latest.min.js"}

use Rack::SockJS, "/echo", options do |connection|
  connection.subscribe do |session, buffer|
    debug "~ \033[0;31;40m[Echo]\033[0m buffer: #{buffer.inspect}, session: #{session.inspect}"
    session.send(*buffer)
  end
end

use Rack::SockJS, "/close", options do |connection|
  connection.session_open do |session|
    debug "~ \033[0;31;40m[Close]\033[0m closing the session ..."
    session.close(3000, "Go away!")
  end
end

run MyHelloWorld.new
