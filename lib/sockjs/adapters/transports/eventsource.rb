# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class EventSource < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/eventsource$/
      self.method  = "GET"

      # Handler.
      def handle(request)
        self.response(request, 200, {"Content-Type" => CONTENT_TYPES[:event_stream], "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"})  { |response| response.set_session_id(request.session_id) }
        @response.write_head

        # Opera needs to hear two more initial new lines.
        @response.write("\r\n")

        self.try_timer_if_valid(request, @response)
      end

      def format_frame(payload)
        # Beware of leading whitespace
        ["data: ", payload, "\r\n\r\n"].join
        # ["data: ", escape_selected(payload, "\r\n\x00"), "\r\n\r\n"].join
      end

      def escape_selected(*args)
        args.join
      end
    end
  end
end
