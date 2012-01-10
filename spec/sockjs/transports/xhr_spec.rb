#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/xhr"

describe SockJS::Transports::XHRPost do
  it_should_match_path  "server/session/xhr"
  it_should_have_method "POST"
  transport_handler_eql "a/b/xhr", "POST"

  describe "#handle(request)" do
    let(:transport) do
      connection = SockJS::Connection.new {}
      session = FakeSession.new(self, Hash.new, :open)
      connection.sessions["b"] = session
      described_class.new(connection, Hash.new)
    end

    let(:request) do
      FakeRequest.new.tap do |request|
        random = Array.new(7) { rand(256) }.pack("C*").unpack("H*").first
        request.path_info = "/a/#{random}/xhr"
      end
    end

    let(:response) do
      transport.handle(request)
    end

    context "with a session" do
      let(:request) do
        FakeRequest.new.tap do |request|
          request.path_info = "/a/b/xhr"
        end
      end

      it "should respond with HTTP 200" do
        response.status.should eql(200)
      end

      it "should respond with plain text MIME type" do
        response.headers["Content-Type"].should match("text/plain")
      end

      it "should run user code" do
        session = transport.connection.sessions["b"]
        session.stub!(:process_buffer).and_return("msg")

        response
      end
    end

    context "without a session" do
      it "should create one and send an opening frame" do
        response # Run the handler.
        request.chunks.last.should eql("o")
      end

      it "should respond with HTTP 200" do
        response.status.should eql(200)
      end

      it "should respond with javascript MIME type" do
        response.headers["Content-Type"].should match("application/javascript")
      end

      it "should set access control" do
        response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
        response.headers["Access-Control-Allow-Credentials"].should eql("true")
      end

      it "should set session ID" do
        cookie = response.headers["Set-Cookie"]
        cookie.should match("JSESSIONID=#{request.session_id}; path=/")
      end
    end
  end
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
