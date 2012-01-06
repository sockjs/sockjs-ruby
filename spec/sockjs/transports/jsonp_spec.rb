#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/jsonp"

class SockJS::Transports::JSONP
  def session_class
    FakeSession
  end
end

describe SockJS::Transports::JSONP do
  it_should_match_path  "server/session/jsonp"
  it_should_have_method "GET"
  transport_handler_eql "a/b/jsonp", "GET"

  describe "#handle(request)" do
    let(:transport) do
      described_class.new(SockJS::Connection.new {}, Hash.new)
    end

    let(:request) do
      @request ||= FakeRequest.new.tap do |request|
        request.path_info = "/echo/a/b/jsonp"
      end
    end

    let(:response) do
      transport.handle(request)
    end

    context "with callback specified" do
      let(:request) do
        @request ||= FakeRequest.new.tap do |request|
          request.path_info = "/echo/a/b/jsonp"
          request.callback = "clbk"
        end
      end

      context "with a session" do
        let(:transport) do
          connection = SockJS::Connection.new {}
          connection.sessions["b"] = FakeSession.new(self, Hash.new)

          described_class.new(connection, Hash.new)
        end

        it "should respond with HTTP 200" do
          response.status.should eql(200)
        end

        it "should respond with plain text MIME type" do
          response.headers["Content-Type"].should match("text/plain")
        end

        it "should respond with a body"
      end

      context "without any session" do
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

        it "should disable caching" do
          response.headers["Cache-Control"].should eql("no-store, no-cache, must-revalidate, max-age=0")
        end

        it "should open a new session"
      end
    end

    context "without callback specified" do
      it "should respond with HTTP 500" do
        response.status.should eql(500)
      end

      it "should respond with HTML MIME type" do
        response.headers["Content-Type"].should match("text/html")
      end

      it "should return error message in the body" do
        response # Run the handler.
        request.chunks.last.should match(/"callback" parameter required/)
      end
    end
  end

  describe "#format_frame(payload)" do
    it "should format payload"
  end
end

describe SockJS::Transports::JSONPSend do
end
