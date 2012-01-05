#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"
require "sockjs/protocol"

describe SockJS::Protocol do
  it "should define OPENING_FRAME" do
    described_class::OPENING_FRAME.should eql("o")
  end

  it "should define CLOSING_FRAME" do
    described_class::CLOSING_FRAME.should eql("c")
  end

  it "should define ARRAY_FRAME" do
    described_class::ARRAY_FRAME.should eql("a")
  end

  it "should define HEARTBEAT_FRAME" do
    described_class::HEARTBEAT_FRAME.should eql("h")
  end

  describe ".array_frame(array)" do
    it "should take only an array as the first argument" do
      -> { described_class.array_frame(Hash.new) }.should raise_error(TypeError)
    end

    it "should return a valid array frame" do
      described_class.array_frame([1, 2, 3]).should eql("a[1,2,3]")
      described_class.array_frame(["tests"]).should eql('a["tests"]')
    end
  end

  describe ".closing_frame(status, message)" do
    it "should take only integer as the first argument" do
      -> { described_class.closing_frame("2010", "message") }.should raise_error(TypeError)
    end

    it "should take only string as the second argument" do
      -> { described_class.closing_frame(2010, :message) }.should raise_error(TypeError)
    end

    it "should return a valid closing frame" do
      -> {
        frame = described_class.closing_frame(2010, "message")
        frame.should eql('c[2010,"message"]')
      }.should_not raise_error(TypeError)
    end
  end
end
