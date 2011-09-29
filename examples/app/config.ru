#!/usr/bin/env rackup
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
  </body>
</html>
    HTML
    [200, {"Content-Type" => "text/html", "Content-Lenght" => body.bytesize.to_s}, [body]]
  end
end

puts "~ Available handlers: #{::SockJS::Adapter.subclasses.inspect}"
use Rack::SockJS
run MyHelloWorld.new
