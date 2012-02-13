#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/session"
require "sockjs/transports/xhr"

class Session < SockJS::Session
  include ResetSessionMixin
end

describe Session do
  subject do
    connection = SockJS::Connection.new {}
    transport  = SockJS::Transports::XHRPost.new(connection, Hash.new)

    def transport.session_finish
    end

    described_class.new(transport, open: Array.new)
  end

  describe "#initialize(transport, callback)"

  describe "#send(data, *args)"

  describe "#finish" do
    it "should raise an error if there's no response assigned"
  end

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

    it "should return false after a session is open" do
      subject.open!
      subject.should_not be_newly_created
    end
  end

  describe "#open?" do
    it "should return false after a new session is created" do
      subject.should_not be_open
    end

    it "should return true after a session is open" do
      subject.open!
      subject.check_status
      subject.should be_open
    end
  end

  describe "#closing?" do
    it "should return false after a new session is created" do
      subject.should_not be_closing
    end
  end

  describe "#closed?"
end




class SessionWitchCachedMessages < SockJS::SessionWitchCachedMessages
  include ResetSessionMixin
end

describe SessionWitchCachedMessages do
end
