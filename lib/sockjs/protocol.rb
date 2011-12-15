# encoding: utf-8

require "json"

module SockJS
  class Protocol
    OPENING_FRAME   ||= "o"
    CLOSING_FRAME   ||= "c"
    ARRAY_FRAME     ||= "a"
    HEARTBEAT_FRAME ||= "h"

    def self.array_frame(array)
      "#{ARRAY_FRAME}#{array.to_json}"
    end

    def self.close_frame(status, message)
      validate Integer, status
      validate String, message

      "#{CLOSING_FRAME}[#{status},#{message.inspect}]"
    end

    protected
    def validate(desired_class, object)
      unless object.is_a?(desired_class)
        raise ArgumentError.new("#{desired_class} object expected, but object is an instance of #{object.class} (object: #{object.inspect}).")
      end
    end
  end
end
