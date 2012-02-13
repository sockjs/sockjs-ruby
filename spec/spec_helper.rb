# encoding: utf-8

module TransportSpecMacros
  def it_should_have_prefix(prefix)
    it "should have prefix #{prefix}" do
      described_class.prefix.should == prefix
    end
  end

  def it_should_match_path(path)
    it "should match path #{path}" do
      described_class.prefix.should match(path)
    end
  end

  def it_should_have_method(method)
    it "should have method #{method}" do
      described_class.method.should == method
    end
  end

  def transport_handler_eql(path, method)
    describe SockJS::Transport do
      describe ".handler(#{path}, #{method})" do
        it "should return #{described_class}" do
          transports = SockJS::Transport.handlers(path)
          transports.find { |transport|
            transport.method == method
          }.should == described_class
        end
      end
    end
  end
end

require "stringio"

class FakeRequest
  attr_reader :chunks
  attr_writer :data
  attr_accessor :path_info, :callback, :if_none_match, :content_type

  def initialize(env = Hash.new)
    self.env.merge!(env)
  end

  def env
    @env ||= {
      "async.callback" => Proc.new do |status, headers, body|
        @chunks = Array.new

        # This is so we can test it.
        # Block passed to body.each will be used
        # as the @body_callback in DelayedResponseBody.
        body.each do |chunk|
          next if chunk == "0\r\n\r\n"
          @chunks << chunk.split("\r\n").last
        end
      end
    }
  end

  def session_id
    "session-id"
  end

  def origin
    "*"
  end

  def fresh?(etag)
    @if_none_match == etag
  end

  def data
    StringIO.new(@data || "")
  end
end

require "sockjs"
require "sockjs/session"

module ResetSessionMixin
  def initialize(connection, callbacks = Hash.new, status = :created)
    super(connection, callbacks)
    @status = status
  end

  def buffer
    @buffer ||= SockJS::Buffer.new
  end

  def set_timer
  end

  def reset_timer
  end

  def reset_close_timer
  end
end

class FakeSession < SockJS::Session
  include ResetSessionMixin
end

require "sockjs/servers/thin"

class SockJS::Thin::Response
  def chunks
    @request.chunks
  end
end

RSpec.configure do |config|
  config.extend(TransportSpecMacros)
  config.before do
    class SockJS::Transport
      def session_class
        FakeSession
      end
    end
  end
end
