# encoding: utf-8

require "spec_helper"
require "sockjs/version"

describe SockJS do
  it "should define VERSION" do
    described_class.constants.should include(:VERSION)
  end
end
