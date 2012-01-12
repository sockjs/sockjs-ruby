#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/websocket"

describe SockJS::Transports::WebSocket do
  it_should_match_path  "server/session/websocket"
  it_should_have_method "GET"
  transport_handler_eql "a/b/websocket", "GET"

  # TODO: This should be a mixin.
  def transport(options = Hash.new)
    connection = SockJS::Connection.new {}
    connection.session_open {}
    # TODO: In fact the first argument should always be the transport,
    # we should replace 'self' by the following code in all the specs.
    described_class.new(connection, options).tap do |transport|
      # TODO: Use Connection#create_session instead of
      # instantiating FakeSession manually.
      connection.create_session("b", transport, FakeSession)
    end
  end

  def request(opts = Hash.new)
    env = {
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_UPGRADE" => "WebSocket"}
    FakeRequest.new(env.merge(opts)).tap do |request|
      request.path_info = "/a/b/websocket"
    end
  end

  def response(transport = transport, request = request)
    transport.handle(request)
  end


  describe "#handle_open(request)" do
    it "should send the opening frame"
    it "should open a new session"
  end

  describe "#handle_message(request, event)" do
    let(:app) do
      Proc.new do |connection|
        connection.subscribe do |session, message|
          session.send(message.upcase)
        end
      end
    end

    it "should receive the message"
    it "should run user code"
    it "should send messages"
  end

  describe "#handle_close(request, event)" do
    it "should send the closing frame"
    it "should open a new session"
  end

  describe "#format_frame(payload)" do
    it "should raise an error if payload is nil" do
      -> { transport.format_frame(nil) }.should raise_error(TypeError)
    end

    it "should return the payload without adding \\n" do
      transport.format_frame("o").should eql("o")
    end
  end
end
