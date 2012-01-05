#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"
require "sockjs"

describe SockJS do
  describe ".connect" do
    it "should work without any arguments" do
      EM.run do
        -> { described_class.connect }.should_not raise_error

        EM.stop
      end
    end

    it "should let you specify options such as port and host" do
      EM.run do
        -> { described_class.connect(host: "localhost", port: 9292) }.should_not raise_error

        EM.stop
      end
    end

    it "should include SockJS::Connection" do
      EM.run do
        connection = described_class.connect
        meta_class = class << connection; self; end
        meta_class.included_modules.should include(described_class::Connection)

        EM.stop
      end
    end
  end
end
