# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class EventSource < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/eventsource$/
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :eventsource]

      # Handler.
      def handle(request)
        # session = transport.Session.bySessionIdOrNew(req.session, req.sockjs_server)
        # session.register( new EventSourceReceiver(res, req.sockjs_server.options) )

        # Opera needs to hear two more initial new lines.
        body = "\r\n\r\n"
        self.write_response(request, 200, {"Content-Type" => CONTENT_TYPES[:event_stream], "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"}, body)  { |response| response.set_session_id(request.session_id) }
      end

      def send_frame(payload)
        # Beware of leading whitespace
        data = ["data: ", escape_selected(payload, "\r\n\x00"), "\r\n\r\n"]
        super(data.join)
      end
    end
  end
end
