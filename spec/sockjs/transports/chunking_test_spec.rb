#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/chunking_test"

describe SockJS::Transports::ChunkingTestOptions do
  it_should_have_prefix "chunking_test"
  it_should_have_method "OPTIONS"

  describe "#handle(request)" do
    let(:transport) do
      described_class.new(Object.new, Hash.new)
    end

    let(:request) do
      @request ||= FakeRequest.new
    end

    let(:response) do
      transport.handle(request)
    end

    it "should respond with HTTP 204" do
      response.status.should eql(204)
    end

    it "should set session ID" do
      cookie = response.headers["Set-Cookie"]
      cookie.should match("JSESSIONID=#{request.session_id}; path=/")
    end

    it "should set access control" do
      response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
      response.headers["Access-Control-Allow-Credentials"].should eql("true")
    end

    it "should set Allow header to OPTIONS, POST" do
      response.headers["Allow"].should eql("OPTIONS, POST")
    end

    it "should set cache control to be valid for the next year" do
      time = Time.now + 31536000

      response.headers["Cache-Control"].should eql("public, max-age=31536000")
      response.headers["Expires"].should eql(time.gmtime.to_s)
      response.headers["Access-Control-Max-Age"].should eql("1000001")
    end

    it "should have an empty body" do
      response # Run the handler.
      request.chunks.should be_empty
    end
  end

end

describe SockJS::Transports::ChunkingTestPost do
end
