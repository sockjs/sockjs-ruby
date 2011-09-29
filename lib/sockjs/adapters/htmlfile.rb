# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class HTMLFile < Adapter
      # Settings.
      self.prefix  = "htmlfile"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :htmlfile]

      # Handler.
      def self.handle(env)
        qs = env["QUERY_STRING"].split("=").each_slice(2).reduce(Hash.new) do |buffer, pair|
          buffer.merge(pair.first => pair.last)
        end

        callback = qs["c"] || qs["callback"]

        if callback
          # Safari needs at least 1024 bytes to parse the website. Relevant:
          #   http://code.google.com/p/browsersec/wiki/Part2#Survey_of_content_sniffing_behaviors
          html = ::DATA.gsub("{{ callback }}", callback)
          body = html + (" " * (1024 - ::DATA.bytesize)) + "\r\n\r\n"
          [200, {"Content-Type" => "text/html", "Content-Length" => body.bytesize.to_s}, [body]]

          # TODO:
          # session = transport.Session.bySessionIdOrNew(req.session, req.sockjs_server)
          # session.register( new HtmlFileReceiver(res, req.sockjs_server.options) )
        else
          body = "You have to specify 'callback' through the query string!"
          [500, {"Content-Type" => "text/html", "Content-Length" => body.bytesize.to_s}, [body]]
        end
      end

      def self.send_frame(payload)
        super( "<script>\np(#{JSON.stringify(payload)});\n</script>\r\n" )
      end
    end
  end
end

__END__
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  </head>

  <body>
    <h2>Don't panic!</h2>
    <script>
      // Browsers fail with "Uncaught exception: ReferenceError: Security
      // error: attempted to read protected variable: _jp". Set
      // document.domain in order to work around that.
      document.domain = document.domain;
      var c = parent.{{ callback }};
      c.start();
      function p(d) {c.message(d);};
      window.onload = function() {c.stop();};
    </script>
  </body>
</html>
