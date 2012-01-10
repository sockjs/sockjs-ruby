#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/websocket"

describe SockJS::Transports::WebSocket do
  it_should_match_path  "server/session/websocket"
  it_should_have_method "GET"
  transport_handler_eql "a/b/websocket", "GET"
end
