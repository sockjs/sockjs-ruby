#!/usr/bin/env gem build
# encoding: utf-8

require "base64"

require File.expand_path("../lib/sockjs/version", __FILE__)

Gem::Specification.new do |s|
  s.name     = "sockjs"
  s.version  = SockJS::VERSION
  s.authors  = ["botanicus"]
  s.email    = "james(at)101ideas.cz"
  s.homepage = "https://github.com/sockjs/sockjs-ruby"
  s.summary  = "Ruby server for SockJS"
  s.description = <<-DESC
    SockJS is a WebSocket emulation library. It means that you use the WebSocket API, only instead of WebSocket class you instantiate SockJS class. In absence of WebSocket, some of the fallback transports will be used. This code is compatible with SockJS protocol #{SockJS::PROTOCOL_VERSION}.
  DESC

  # Ruby version
  s.required_ruby_version = ::Gem::Requirement.new("~> 1.9")

  # Dependencies
  s.add_dependency "rack"
  s.add_dependency "thin"
  s.add_dependency "faye-websocket", "~> 0.4.3"

  # Files
  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.extra_rdoc_files = ["README.textile"]

  # RubyForge
  s.rubyforge_project = "sockjs"

  # First steps
  s.post_install_message = %Q{
=> \e[31mWelcome to SockJS #{SockJS::VERSION}!\e[0m

[\e[32mBasic Info\e[0m]

\e[33m*\e[0m This release is compatible with SockJS protocol \e[34m#{SockJS::PROTOCOL_VERSION}\e[0m.
\e[33m*\e[0m This is a first public release, consider it experimental.
\e[33m*\e[0m If you encounter any problems, please open an issue on GitHub.


[\e[32mBasic Example\e[0m]

=> \e[33mClient Side\e[0m

\e[36m<\e[0m\e[31mscript\e[0m \e[36msrc\e[0m=\e[34m"http://cdn.sockjs.org/sockjs-0.2.1.min.js"\e[36m>\e[0m\e[36m</\e[0m\e[31mscript\e[36m>\e[0m

\e[36m<\e[0m\e[31mscript\e[36m>\e[0m
  \e[32mvar\e[0m sock = \e[32mnew SockJS\e[0m(\e[34m"http://mydomain.com/my_prefix"\e[0m);

  \e[35m// Events: onopen, onmessage, onclose.\e[0m
  sock.onmessage = \e[32mfunction\e[0m(e) {
    console.log(\e[34m"message"\e[0m, e.data);
  };
\e[36m</\e[0m\e[31mscript\e[36m>\e[0m


=> \e[33mServer Side\e[0m

\e[35m# Run one SockJS app on /echo.\e[0m
use \e[32mSockJS\e[0m, \e[34m"/echo"\e[0m \e[31mdo\e[0m \e[31m|\e[36mconnection\e[31m|\e[0m
  connection.subscribe \e[31mdo\e[0m \e[31m|\e[36msession, message\e[31m|\e[0m
    session.send(message)
  \e[31mend\e[0m
\e[31mend\e[0m

\e[35m# Your main app, anything else than /echo/*.\e[0m
run \e[32mMyMainApp\e[0m.\e[32mnew\e[0m

... for more info check README!
  }
end
