#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/iframe"

describe SockJS::Transports::IFrame do
  it_should_match_path  "iframe.html"
  it_should_match_path  "iframe1.html"
  it_should_match_path  "iframe-1.html"
  it_should_have_method "GET"
  transport_handler_eql "iframe.1.html", "GET"


  describe "#handle(request)" do
    let(:transport) do
      connection = SockJS::Connection.new {}
      described_class.new(connection, sockjs_url: "http://sock.js/sock.js")
    end

    let(:response) do
      transport.handle(request)
    end

    context "If-None-Match header matches ETag of current body" do
      let(:request) do
        @request ||= FakeRequest.new.tap do |request|
          etag = '"af0ca7deb5298aeb946c4f7b96d1501b"'
          request.if_none_match = etag
          request.path_info = "/iframe.html"
        end
      end

      it "should respond with HTTP 304" do
        response.status.should eql(304)
      end
    end

    context "If-None-Match header doesn't match ETag of current body" do
      let(:request) do
        @request ||= FakeRequest.new.tap do |request|
          request.path_info = "/iframe.html"
        end
      end

      it "should respond with HTTP 200" do
        response.status.should eql(200)
      end

      it "should respond with HTML MIME type" do
        response.headers["Content-Type"].should match("text/html")
      end

      it "should set ETag header"

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        response.headers["Cache-Control"].should eql("public, max-age=31536000")
        response.headers["Expires"].should eql(time.gmtime.to_s)
        response.headers["Access-Control-Max-Age"].should eql("1000001")
      end

      it "should return HTML wrapper in the body" do
        response # Run the handler.
        request.chunks.last.should match(/document.domain = document.domain/)
      end

      it "should set sockjs_url" do
        response # Run the handler.
        request.chunks.last.should match(transport.options[:sockjs_url])
      end
    end
  end

  describe "#etag(body)" do
    subject do
      described_class.new(Object.new, Hash.new)
    end

    it "must be same for the same string" do
      subject.etag("test").should eql(subject.etag("test"))
    end
  end
end
