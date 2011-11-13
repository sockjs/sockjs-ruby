# encoding: utf-8

require "digest/md5"

require_relative "../adapter"

# ['GET', p('/iframe[0-9-.a-z_]*.html'), ['iframe', 'cache_for', 'expose']],
module SockJS
  module Adapters
    class IFrame < Adapter
      # Settings.
      self.prefix  = /iframe[0-9\-.a-z_]*.html/
      self.method  = "GET"
      self.filters = [:iframe, :cache_for, :expose]

      # Handler.
      def handle(env)
        # Copied from the HTML file adapter.
        data = begin
          lines = File.readlines(__FILE__)
          index = lines.index("__END__\n")
          lines[(index + 1)..-1].join("")
        end

        body = data.gsub("{{ sockjs_url }}", options[:sockjs_url])
        headers = self.headers(body)

        if env["HTTP_IF_NONE_MATCH"] == headers["ETag"]
          self.response.write_head(304, Hash.new)
          self.response.finish
        else
          self.response.write_head(200, headers)
          self.response.finish(body)
        end
      end

      def headers(body)
        year = 31536000
        time = Time.now + year

        {
          "Content-Type"  => "text/html; charset=UTF-8",
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
