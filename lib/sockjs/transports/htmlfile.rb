# encoding: utf-8

require "json"
require "sockjs/adapter"

module SockJS
  module Adapters
    class HTMLFile < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/htmlfile$/
      self.method  = "GET"

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

          respond(request, 200) do |response, session|
            response.set_header("Content-Type", CONTENT_TYPES[:html])
            response.set_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            response.write(body)

            self.try_timer_if_valid(request, response)
          end
        else
          self.error(500, :html, '"callback" parameter required')
        end
      end

      def format_frame(payload)
        raise TypeError.new if payload.nil?

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
