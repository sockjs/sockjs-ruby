# encoding: utf-8

module SockJS
  class Protocol
    OPEN_FRAME  ||= "o\n"
    CLOSE_FRAME ||= "c\n"
    ARRAY_FRAME ||= "a"

    HEARTBEAT_FRAME ||= "h\n"

    def self.array_frame(data)
      "#{ARRAY_FRAME}#{data}\n"
    end
  end
end
