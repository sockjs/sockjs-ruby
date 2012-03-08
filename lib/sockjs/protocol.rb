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

      "#{ARRAY_FRAME}#{self.escape(array.to_json)}"
    end

    def self.closing_frame(status, message)
      validate Integer, status
      validate String, message

      "#{CLOSING_FRAME}[#{status},#{self.escape(message.inspect)}]"
    end


    # JSON Unicode Encoding
    # =====================
    #
    # SockJS takes the responsibility of encoding Unicode strings for
    # the user. The idea is that SockJS should properly deliver any
    # valid string from the browser to the server and back. This is
    # actually quite hard, as browsers do some magical character
    # translations. Additionally there are some valid characters from
    # JavaScript point of view that are not valid Unicode, called
    # surrogates (JavaScript uses UCS-2, which is not really Unicode).
    #
    # Dealing with unicode surrogates (0xD800-0xDFFF) is quite special.
    # If possible we should make sure that server does escape decode
    # them. This makes sense for SockJS servers that support UCS-2
    # (SockJS-node), but can't really work for servers supporting unicode
    # properly (Python).
    #
    # The server can't send Unicode surrogates over Websockets, also various
    # \u2xxxx chars get mangled. Additionally, if the server is capable of
    # handling UCS-2 (ie: 16 bit character size), it should be able to deal
    # with Unicode surrogates 0xD800-0xDFFF:
    # http://en.wikipedia.org/wiki/Mapping_of_Unicode_characters#Surrogates
    def self.escape(string)
      string.dup.tap do |string|
        time = Time.timer do
          (255..65536).each do |int|
            begin
              character = int.chr(Encoding::UTF_8)
              char_rexp = Regexp.new(character, "u")
              escaped   = '\u%04x' % (int)
              string.gsub!(char_rexp, escaped)
            rescue RegexpError => error
            end
          end
        end

        puts "It took #{time} to escape the characters."
      end
    end

    def self.validate(desired_class, object)
      unless object.is_a?(desired_class)
        raise TypeError.new("#{desired_class} object expected, but object is an instance of #{object.class} (object: #{object.inspect}).")
      end
    end
  end
end
