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
        response = self.response(request, 200, {"Content-Type" => CONTENT_TYPES[:event_stream], "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"})  { |response| response.set_session_id(request.session_id) }
        response.write_head

        # Opera needs to hear two more initial new lines.
        response.write("\r\n")

        match = request.path_info.match(self.class.prefix)

        unless session = self.connection.sessions[match[1]]
          session = self.connection.create_session(match[1])
          body = self.format_frame(session.open!.chomp)
          response.write(body)
        end

        EM::PeriodicTimer.new(1) do |timer|
          if data = session.process_buffer
            response.write(format_frame(data.chomp!)) unless data == "a[]\n" # FIXME
            if data[0] == "c" # close frame. TODO: Do this by raising an exception or something, this is a mess :o Actually ... do we need here some 5s timeout as well?
              timer.cancel
              response.finish
            end
          end
        end
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
