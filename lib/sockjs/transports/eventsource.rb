# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports
    class EventSource < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/eventsource$/
      self.method  = "GET"

      # Handler.
      def handle(request)
        response(request, 200, session: :create) do |response, session|
          response.set_content_type(:event_stream)
          response.set_session_id(request.session_id)
          response.set_no_cache
          response.write_head

          # Opera needs to hear two more initial new lines.
          response.write("\r\n")

          if session.newly_created?
            # response.write(self.format_frame(session.open!))
            response.write("data: o\r\n\r\n")
          end

          session.init_timer(response)
        end
      end

      def format_frame(payload)
        raise TypeError.new if payload.nil?

        # Beware of leading whitespace
        ["data: ", payload, "\r\n\r\n"].join
        # ["data: ", escape_selected(payload, "\r\n\x00"), "\r\n\r\n"].join
      end

      def send(session, data, *args)
        session.buffer.messages.clear << data[9..-8] # Alright, this is a hardcore hack.
      end

      def session_finish(frame)
        frame
      end
    end
  end
end
