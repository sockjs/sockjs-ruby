# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class EventSource < Adapter
      # Settings.
      self.prefix  = "eventsource"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :eventsource]

      # Handler.
      def handle(env)
        # session = transport.Session.bySessionIdOrNew(req.session, req.sockjs_server)
        # session.register( new EventSourceReceiver(res, req.sockjs_server.options) )

        # Opera needs to hear two more initial new lines.
        body = "\r\n\r\n"
        [200, {"Content-Type" => "text/event-stream"}, [body]]
      end

      def self.send_frame(payload)
        # Beware of leading whitespace
        data = ["data: ", escape_selected(payload, "\r\n\x00"), "\r\n\r\n"]
        super(data.join)
      end
    end
  end
end
