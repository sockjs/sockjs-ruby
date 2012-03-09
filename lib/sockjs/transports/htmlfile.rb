# encoding: utf-8

require "json"
require "sockjs/transport"

module SockJS
  module Transports
    class HTMLFile < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/htmlfile$/
      self.method  = "GET"

      def session_class
        SockJS::Session
      end

      # Handler.
      def handle(request)
        if request.callback
          # TODO: Investigate why we can't use __DATA__
          data = begin
            lines = File.readlines(__FILE__)
            index = lines.index("__END__\n")
            lines[(index + 1)..-1].join("")
          end

          # Safari needs at least 1024 bytes to parse the website. Relevant:
          #   http://code.google.com/p/browsersec/wiki/Part2#Survey_of_content_sniffing_behaviors
          html = data.gsub("{{ callback }}", request.callback)
          body = html + (" " * (1024 - html.bytesize)) + "\r\n\r\n"

          response(request, 200, session: :create) do |response, session|
            response.set_content_type(:html)
            response.set_no_cache
            response.set_session_id(request.session_id)

            response.write(body)

            if session.newly_created?
              session.open!
            end

            session.wait(response)
          end
        else
          respond(request, 500) do |response|
            response.set_content_type(:html)
            response.write('"callback" parameter required')
          end
        end
      end

      def format_frame(payload)
        raise TypeError.new("Payload must not be nil!") if payload.nil?

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
