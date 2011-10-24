#!/usr/bin/env rackup -s thin -p 8080
# encoding: utf-8

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "rack/sockjs"

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
  connection.subscribe do |message|
    connection.send(message)
  end
end

use Rack::SockJS, "/close", options do |connection|
  connection.close(3000, "Go away!")
end

run MyHelloWorld.new
