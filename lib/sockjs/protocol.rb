# encoding: utf-8

require "json"

module SockJS
  module Protocol
    OPENING_FRAME   ||= "o"
    CLOSING_FRAME   ||= "c"
    ARRAY_FRAME     ||= "a"
    HEARTBEAT_FRAME ||= "h"

    def self.array_frame(array)
      validate Array, array

      "#{ARRAY_FRAME}#{array.to_json}"
    end

    def self.closing_frame(status, message)
      validate Integer, status
      validate String, message

      "#{CLOSING_FRAME}[#{status},#{message.inspect}]"
    end

    def self.validate(desired_class, object)
      unless object.is_a?(desired_class)
        raise TypeError.new("#{desired_class} object expected, but object is an instance of #{object.class} (object: #{object.inspect}).")
      end
    end
  end
end
