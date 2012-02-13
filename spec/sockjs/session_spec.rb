#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/session"

class Session < SockJS::Session
  include ResetSessionMixin
end

describe Session do
  subject do
    described_class.new(nil, Hash.new)
  end

  describe "#initialize(transport, callback)"

  describe "#send(data, *args)"

  describe "#finish"

  describe "#receive_message"

  describe "#process_messages" # ?

  describe "#process_buffer" # ?

  describe "#create_response" # ?

  describe "#check_status" # ?

  describe "#open!(*args)"

  describe "#close(status, message)"

  describe "#newly_created?" do
    it "should return true after a new session is created" do
      subject.should be_newly_created
    end
  end

  describe "#open?"

  describe "#closing?"

  describe "#closed?"
end




class SessionWitchCachedMessages < SockJS::SessionWitchCachedMessages
  include ResetSessionMixin
end

describe SessionWitchCachedMessages do
end
