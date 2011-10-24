# encoding: utf-8

module SockJS
  class Protocol
    OPEN_FRAME  ||= "o\n"
    CLOSE_FRAME ||= "c"
    ARRAY_FRAME ||= "a"

    HEARTBEAT_FRAME ||= "h\n"

    def self.array_frame(data)
      "#{ARRAY_FRAME}#{data}\n"
    end

    def self.close_frame(status, message)
      if status && message
        "#{CLOSE_FRAME}[#{status},#{message.inspect}]\n"
      else
        CLOSE_FRAME + "\n"
      end
    end
  end
end
