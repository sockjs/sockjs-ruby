# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports
    class EventSource < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/eventsource$/
      self.method  = "GET"

      def session_class
        SockJS::Session
      end

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
            session.open!
          end

          session.wait(response)
        end
      end

      def format_frame(payload)
        raise TypeError.new("Payload must not be nil!") if payload.nil?

        ["data: ", payload, "\r\n\r\n"].join
      end
    end
  end
end
