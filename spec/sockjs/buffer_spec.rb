# encoding: utf-8

require "sockjs/buffer"

describe SockJS::Buffer do
  describe "#initialize(status = nil)" do
    it "should work without any status specified" do
      described_class.new.should be_newly_created
    end

    it "should work with a status specified" do
      described_class.new(:open).should be_open
    end

    it "should fail if given status doesn't exist" do
      -> { described_class.new(:test) }.should raise_error(ArgumentError)
    end
  end

  describe "#to_frame" do
    it "should return opening frame if the buffer is about to be open" do
      subject.open
      subject.to_frame.should eql("o")
    end

    it "should return closing frame if the buffer is about to be closed" do
      subject = described_class.new(:open)
      subject.close(2010, "Bye, bye!")
      subject.to_frame.should eql('c[2010,"Bye, bye!"]')
    end

    it "should return array frame with all the messages otherwise" do
      subject = described_class.new(:open)
      subject.to_frame.should eql('a[]')

      subject << "Hello"
      subject.to_frame.should eql('a["Hello"]')

      subject << "world"
      subject.to_frame.should eql('a["Hello","world"]')
    end
  end


  # === Status changing methods. === #

  describe "#open" do
    [:open, :opening, :closing, :closed].each do |status|
      it "should fail if status is #{status}" do
        -> { described_class.new(status).open }.should raise_error(SockJS::StateMachineError)
      end
    end

    it "should change status to opening" do
      subject.should be_newly_created
      subject.open
      subject.should be_opening
    end
  end

  describe "#close(status, message)" do
    subject { described_class.new(:open) }

    [:newly_created, :opening, :closing, :closed].each do |status|
      it "should fail if status is #{status}" do
        -> { described_class.new(status).close(2010, "") }.should raise_error(SockJS::StateMachineError)
      end
    end

    it "should change status to closing" do
      subject.should be_open
      subject.close(2010, "Test")
      subject.should be_closing
    end
  end


  # === Methods manipulating messages. === #

  describe "#<<(message)" do
    it "should fail if the buffer isn't open yet" do
      -> { subject << "test" }.should raise_error(SockJS::BufferNotOpenError)
    end

    it "should add a message if the buffer is open" do
      subject = described_class.new(:open)
      -> { subject << "test" }.should_not raise_error(SockJS::BufferNotOpenError)

      subject.to_frame.should eql('a["test"]')
    end

    it "should fail if the buffer is just opening" do
      subject = described_class.new(:opening)
      -> { subject << "test" }.should raise_error(SockJS::BufferNotOpenError)
    end

    it "should fail if the buffer is closing" do
      subject = described_class.new(:closing)
      -> { subject << "test" }.should raise_error(SockJS::BufferNotOpenError)
    end

    it "should fail if the buffer is already closed" do
      subject = described_class.new(:closed)
      -> { subject << "test" }.should raise_error(SockJS::BufferNotOpenError)
    end
  end

  describe "#push(*messages)" do
    it "should be able to push more messages to the buffer" do
      subject = described_class.new(:open)
      subject.push("test", "test")
      subject.to_frame.should eql('a["test","test"]')
    end
  end

  # === Status reporting methods. === #
  it "should have #newly_created?" do
    described_class.new.should be_newly_created
  end

  it "should have #opening?" do
    described_class.new(:opening).should be_opening
  end

  it "should have #open?" do
    described_class.new(:open).should be_open
  end

  it "should have #closing?" do
    described_class.new(:closing).should be_closing
  end

  it "should have #closed?" do
    described_class.new(:closed).should be_closed
  end
end
