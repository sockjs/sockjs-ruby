# encoding: utf-8

module SockJS
  class Protocol
    OPEN_FRAME ||= "o"
    HEARTBEAT_FRAME ||= "h"
    ARRAY_FRAME ||= "a"
    CLOSE_FRAME ||= "c"

    def self.array_frame(data)
      "#{ARRAY_FRAME}#{data}"
    end
  end
end
