#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"
require "sockjs/version"

describe SockJS do
  it "should define VERSION" do
    constants = described_class.constants.map(&:to_sym)
    constants.should include(:VERSION)
  end

  it "should define PROTOCOL_VERSION" do
    constants = described_class.constants.map(&:to_sym)
    constants.should include(:PROTOCOL_VERSION)
  end
end
