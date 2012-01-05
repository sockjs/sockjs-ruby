# encoding: utf-8

module TransportSpecMacros
  def it_should_have_prefix(prefix)
    described_class.prefix.should == prefix
  end

  def it_should_match_path(path)
    described_class.prefix.should =~ path
  end

  def it_should_have_method(method)
    described_class.method.should == method
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

class FakeRequest
  attr_reader :chunks

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

  def method_missing(method, *args, &block)
    puts "~ Please define #{method}(#{args.inspect[1..-2]})"
    super
  end
end

RSpec.configure do |config|
  config.extend(TransportSpecMacros)
end
