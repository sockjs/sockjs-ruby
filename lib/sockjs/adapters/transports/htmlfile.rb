# encoding: utf-8

require "json"
require "sockjs/adapter"

module SockJS
  module Adapters
    class HTMLFile < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/htmlfile$/
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :htmlfile]

      # Handler.
      def handle(request)
        if request.callback
          # What the fuck is wrong with Ruby???
          # The bloody pseudoconstant ::DATA is supposed
          # to be avaible anywhere where we have __END__!
          data = begin
            lines = File.readlines(__FILE__)
            index = lines.index("__END__\n")
            lines[(index + 1)..-1].join("")
          end

          # Safari needs at least 1024 bytes to parse the website. Relevant:
          #   http://code.google.com/p/browsersec/wiki/Part2#Survey_of_content_sniffing_behaviors
          html = data.gsub("{{ callback }}", request.callback)
          body = html + (" " * (1024 - html.bytesize)) + "\r\n\r\n"

          response = self.response(request, 200,
            {"Content-Type" => CONTENT_TYPES[:html], "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"}) { |response| response.set_session_id(request.session_id) }
          response.write_head
          response.write(body)

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

          # TODO: wait for the messages.
        else
          self.write_response(request, 500,
            {"Content-Type" => CONTENT_TYPES[:html]}, '"callback" parameter required')
        end
      end

      def format_frame(payload)
        "<script>\np(#{payload.to_json});\n</script>\r\n"
      end
    end
  end
end

__END__
<!doctype html>
<html><head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head><body><h2>Don't panic!</h2>
  <script>
    document.domain = document.domain;
    var c = parent.{{ callback }};
    c.start();
    function p(d) {c.message(d);};
    window.onload = function() {c.stop();};
  </script>
