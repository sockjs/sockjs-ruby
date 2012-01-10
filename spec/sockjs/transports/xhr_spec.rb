#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/xhr"

describe SockJS::Transports::XHRPost do
  it_should_match_path  "server/session/xhr"
  it_should_have_method "POST"
  transport_handler_eql "a/b/xhr", "POST"
end




describe SockJS::Transports::XHROptions do
  it_should_match_path  "server/session/xhr"
  it_should_have_method "OPTIONS"
  transport_handler_eql "a/b/xhr", "OPTIONS"
end





describe SockJS::Transports::XHRSendPost do
  it_should_match_path  "server/session/xhr_send"
  it_should_have_method "POST"
  transport_handler_eql "a/b/xhr_send", "POST"
end





describe SockJS::Transports::XHRSendOptions do
  it_should_match_path  "server/session/xhr_send"
  it_should_have_method "OPTIONS"
  transport_handler_eql "a/b/xhr_send", "OPTIONS"
end





describe SockJS::Transports::XHRStreamingPost do
  it_should_match_path  "server/session/xhr_streaming"
  it_should_have_method "POST"
  transport_handler_eql "a/b/xhr_streaming", "POST"
end





describe SockJS::Transports::XHRStreamingOptions do
  it_should_match_path  "server/session/xhr_streaming"
  it_should_have_method "OPTIONS"
  transport_handler_eql "a/b/xhr_streaming", "OPTIONS"
end
