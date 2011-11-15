# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class XHRPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_poll]

      # Handler.
      def handle(request)
        match = env["PATH_INFO"].match(self.class.prefix)
        if session = self.connection.sessions[match[1]]
          body = session.process_buffer

          unless body.respond_to?(:bytesize)
            raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
          end

          self.write_response(200, {"Content-Type" => CONTENT_TYPES[:plain]}, body)
        else
          session = self.connection.create_session(match[1])
          body = session.open!
          origin = env["HTTP_ORIGIN"] || "*"
          jsessionid = Rack::Request.new(env).cookies["JSESSIONID"]

          self.write_response(200, {"Content-Type" => CONTENT_TYPES[:javascript], "Set-Cookie" => "JSESSIONID=#{jsessionid || "dummy"}; path=/", "Access-Control-Allow-Origin" => origin, "Access-Control-Allow-Credentials" => "true"}, body)
        end
      end
    end

    class XHROptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(request)
        year = 31536000
        time = Time.now + year
        origin = env["HTTP_ORIGIN"] || "*"
        [204, {"Allow" => "OPTIONS, POST", "Access-Control-Max-Age" => "2000000", "Cache-Control" => "public, max-age=#{year}", "Expires" => time.gmtime.to_s, "Access-Control-Allow-Origin" => origin, "Access-Control-Allow-Credentials" => "true", "Set-Cookie" => "JSESSIONID=dummy; path=/"}, Array.new]
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :xhr_send]

      # Handler.
      def handle(request)
        match = env["PATH_INFO"].match(self.class.prefix)
        session_id = match[1]
        session = self.connection.sessions[session_id]
        if session
          session.receive_message(env["rack.input"].read)

          # When we use HTTP 204 with Content-Type, Rack::Lint
          # will be bitching about it. That's understandable,
          # as Lint is suppose to make sure that given response
          # is valid according to the HTTP standard. However
          # what's totally sick is that Lint is included by default
          # in the development mode. It'd be really dishonest
          # to change this behaviour, regardless how jelly brain
          # minded it is. Funnily enough users can't deactivate
          # Lint either in development, so we'll have to tell them
          # to hack it. Bloody hell, that just can't be happening!
          origin = env["HTTP_ORIGIN"] || "*"

          self.write_response(204, {"Content-Type" => CONTENT_TYPES[:plain], "Set-Cookie" => "JSESSIONID=dummy; path=/", "Access-Control-Allow-Origin" => origin, "Access-Control-Allow-Credentials" => "true"}, "")
        else
          self.write_response(404, {"Content-Type" => CONTENT_TYPES[:plain], "Set-Cookie" => "JSESSIONID=dummy; path=/"}, "Session is not open!")
        end
      rescue SockJS::HttpError => error
        error.to_response
      end
    end

    class XHRSendOptions < XHROptions
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]
    end

    class XHRStreamingPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_streaming]

      # Handler.
      def handle(request)
        match = env["PATH_INFO"].match(self.class.prefix)
        session_id = match[1]
        unless session = self.connection.sessions[session_id]
          session = self.connection.create_session(match[1])

          # IE requires 2KB prefix:
          # http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
          body = "h" * 2049 + "\n"

          body = session.open!
        end

        self.write_response(200, {"Content-Type" => CONTENT_TYPES[:javascript]}, body)
      end
    end

    class XHRStreamingOptions < XHROptions
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]
    end
  end
end
