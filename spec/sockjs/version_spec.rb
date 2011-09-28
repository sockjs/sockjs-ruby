# encoding: utf-8

require "spec_helper"
require "sockjs/version"

describe SockJS do
  it "should define VERSION" do
    constants = described_class.constants.map(&:to_sym)
    constants.should include(:VERSION)
  end
end
