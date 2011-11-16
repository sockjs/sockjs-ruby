# encoding: utf-8

require "digest/md5"
require "sockjs/adapter"

# ['GET', p('/iframe[0-9-.a-z_]*.html'), ['iframe', 'cache_for', 'expose']],
module SockJS
  module Adapters
    class IFrame < Adapter
      # Settings.
      self.prefix  = /iframe[0-9\-.a-z_]*.html/
      self.method  = "GET"
      self.filters = [:iframe, :cache_for, :expose]

      # Handler.
      def handle(request)
        # Copied from the HTML file adapter.
        data = begin
          lines = File.readlines(__FILE__)
          index = lines.index("__END__\n")
          lines[(index + 1)..-1].join("")
        end

        body = data.gsub("{{ sockjs_url }}", options[:sockjs_url])
        headers = self.headers(body)

        if request.headers["if-none-match"] == headers["ETag"]
          self.write_response(304, Hash.new, body)
        else
          self.write_response(200, self.headers, body)
        end
      end

      def headers(body)
        year = 31536000
        time = Time.now + year

        {
          "Content-Type"  => CONTENT_TYPES[:html]
          "ETag"          => '"' + self.digest.hexdigest(body) + '"',
          "Cache-Control" => "public, max-age=#{year}",
          "Expires"       => time.gmtime.to_s,
        }
      end

      def digest
        @digest ||= Digest::MD5.new
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
  <script>
    document.domain = document.domain;
    _sockjs_onload = function(){SockJS.bootstrap_iframe();};
  </script>
  <script src="{{ sockjs_url }}"></script>
</head>
<body>
  <h2>Don't panic!</h2>
  <p>This is a SockJS hidden iframe. It's used for cross domain magic.</p>
</body>
</html>
