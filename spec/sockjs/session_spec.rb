#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/session"
require "sockjs/transports/xhr"

class Session < SockJS::Session
  include ResetSessionMixin

  def set_status_for_tests(status)
    @buffer = SockJS::Buffer.new(status)
    @status = status
    self
  end
end

describe Session do
  subject do
    connection = SockJS::Connection.new {}
    transport  = SockJS::Transports::XHRPost.new(connection, Hash.new)

    def transport.send
    end

    described_class.new(transport, open: Array.new)
  end

  describe "#initialize(transport, callback)" do
    it "should take two arguments" do
      -> { described_class.new(1, 2) }.should_not raise_error(ArgumentError)
    end
  end

  describe "#send(data, *args)" do
    before(:each) do
      @subject = subject
      @subject.buffer = SockJS::Buffer.new(:open)
    end

    it "should add given message to the buffer" do
      @subject.send("test")
      @subject.buffer.messages.should include("test\n")
    end

    it "should pass optional arguments to transport.format_frame" do
      @subject.send("test", test: true)
    end
  end

  describe "#finish" do
    describe "transport responds to #send" do
      it "should call transport.send"
    end

    describe "transport doesn't respond to #send" do
      it "should raise an error if there's no response assigned"
      it "should finish the response with the current buffer content"
    end
  end

  describe "#receive_message" do
    it "should change status from :opening to :open"
    it "should succeed if the message is a valid JSON-like string"
  end

  describe "#process_buffer" do
    it "should reset the timer"
    it "should cache an error"
    it "should change status from :opening to :open"
    it "should execute :buffer callback for each received message"
    it "should return a frame"
  end

  describe "#create_response(&block)" do
    it "should execute the block" do
      lambda {
        subject.create_response do
          raise "Test"
        end
      }.should raise_error("Test")
    end

    it "should return a frame" do
      sub = subject.set_status_for_tests(:open)
      ret = sub.create_response {}
      ret.should eql("a[]")
    end

    it "should return a closing frame if SockJS::CloseError occured" do
      sub = subject.set_status_for_tests(:open)
      ret = sub.create_response do
        raise SockJS::CloseError.new(3000, "test")
      end
      ret.should eql("c[3000,\"test\"]")
    end
  end

  describe "#check_status" do
    before(:each) do
      @subject = subject.set_status_for_tests(:opening)

      def @subject.callback_run
        @callback_run
      end

      def @subject.callback_run=(status)
        @callback_run = status
      end

      @subject.callbacks[:open] << Proc.new do |session|
        session.callback_run = true
      end
    end

    it "should execute the open callback" do
      @subject.check_status
      @subject.callback_run.should be_true
    end

    it "should change status fro opening to open" do
      @subject.check_status
      @subject.should be_open
    end

    it "should do nothing if status isn't opening" do
      @subject.set_status_for_tests(:closed)

      @subject.check_status
      @subject.should_not be_open
      @subject.callback_run.should be_false
    end
  end

  describe "#open!(*args)" do
    it "should change status to opening" do
      @subject = subject
      @subject.open!
      @subject.should be_opening
    end

    it "should call session.set_timer" do
      @subject = subject
      @subject.should_receive(:set_timer)
      @subject.open!
    end

    it "should open the buffer" do
      @subject = subject
      @subject.open!
      @subject.buffer.to_frame.should eql("o")
    end

    it "should call the session.finish method" do
      @subject = subject.set_status_for_tests(:open)
      transport = @subject.instance_variable_get(:@transport)
      transport.should_receive(:send)

      @subject.close
    end
  end

  describe "#close(status, message)" do
    it "should take either status and message or just a status or no argument at all" do
      -> { subject.close }.should_not raise_error(ArgumentError)
      -> { subject.close(3000) }.should_not raise_error(ArgumentError)
      -> { subject.close(3000, "test") }.should_not raise_error(ArgumentError)
    end

    it "should fail if the user is trying to close a newly created instance" do
      -> { subject.close }.should raise_error(RuntimeError)
    end

    it "should set status to closing" do
      @subject = subject.set_status_for_tests(:open)
      def @subject.reset_close_timer; end
      @subject.close
      @subject.should be_closing
    end

    it "should set frame to the close frame" do
      @subject = subject.set_status_for_tests(:open)
      @subject.close
      @subject.buffer.to_frame.should eql("c[3000,\"Go away!\"]")
    end

    it "should set pass the exit status to the buffer" do
      @subject = subject.set_status_for_tests(:open)
      @subject.close
      @subject.buffer.to_frame.should match(/c\[3000,/)
    end

    it "should set pass the exit message to the buffer" do
      @subject = subject.set_status_for_tests(:open)
      @subject.close
      @subject.buffer.to_frame.should match(/"Go away!"/)
    end

    it "should call the session.finish method" do
      @subject = subject.set_status_for_tests(:open)
      transport = @subject.instance_variable_get(:@transport)
      transport.should_receive(:send)

      @subject.close
    end
  end

  describe "#newly_created?" do
    it "should return true after a new session is created" do
      subject.should be_newly_created
    end

    it "should return false after a session is open" do
      subject.open!
      subject.should_not be_newly_created
    end
  end

  describe "#opening?" do
    it "should return false after a new session is created" do
      subject.should_not be_opening
    end

    it "should return true after a session is open" do
      subject.open!
      subject.should be_opening
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
    before do
      @subject = subject

      def @subject.reset_close_timer
      end
    end

    it "should return false after a new session is created" do
      @subject.should_not be_closing
    end

    it "should return true after session.close is called" do
      @subject.set_status_for_tests(:open)

      @subject.close
      @subject.should be_closing
    end
  end

  describe "#closed?" do
    it "should return false after a new session is created" do
      subject.should_not be_closed
    end

    it "should return true after session.close is called" do
      @subject = subject.set_status_for_tests(:open)
      @subject.should_not be_closed

      @subject.close
      @subject.should be_closed
    end
  end
end




class SessionWitchCachedMessages < SockJS::SessionWitchCachedMessages
  include ResetSessionMixin
end

describe SessionWitchCachedMessages do
end
