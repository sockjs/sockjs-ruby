# encoding: utf-8

require "json"
require "uri"

require_relative "../adapter"

module SockJS
  module Adapters
    class HTMLFile < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/htmlfile$/
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :htmlfile]

      # Handler.
      def handle(env)
        qs = env["QUERY_STRING"].split("=").each_slice(2).reduce(Hash.new) do |buffer, pair|
          buffer.merge(pair.first => pair.last)
        end

        callback = qs["c"] || qs["callback"]

        if callback
          callback = URI.unescape(callback)
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
          html = data.gsub("{{ callback }}", callback)
          body = html + (" " * (1024 - html.bytesize)) + "\r\n\r\n"

          # OK that's not going to fly, is it?
          # This is polling, we write the first part and then we write messages wrapped in script tag and p() call.

          # The only option I can think of is to rewrite #each so it waits ...
          # def each(&block)
          #   loop do
          #     block.call(data) if data = get_data
          #     sleep 0.1
          #   end
          # end

          # OK, forget it, that's bollocks, let's implement it once we'll have EM infrastructure in place.
          self.response.write_head(200, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s, "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0", "Set-Cookie" => "JSESSIONID=dummy; path=/"})
          self.response.finish(body)

          # TODO:
          # session = transport.Session.bySessionIdOrNew(req.session, req.sockjs_server)
          # session.register( new HtmlFileReceiver(res, req.sockjs_server.options) )
        else
          body = '"callback" parameter required'
          self.response.write_head(500, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s})
          self.response.finish(body)
        end
      end

      def send_frame(payload)
        super("<script>\np(#{payload.to_json});\n</script>\r\n")
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
