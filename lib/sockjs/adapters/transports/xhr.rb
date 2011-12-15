# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class XHRPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_poll]

      # Handler.
      def handle(request)
        match = request.path_info.match(self.class.prefix)
        if session = self.connection.sessions[match[1]]
          body = session.process_buffer

          unless body.respond_to?(:bytesize)
            raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
          end

          self.write_response(request, 200, {"Content-Type" => CONTENT_TYPES[:plain]}, body)
        else
          session = self.connection.create_session(match[1], self)
          session.open!

          self.write_response(request, 200, {"Content-Type" => CONTENT_TYPES[:javascript], "Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true"}, body) do |response|
            response.set_session_id(request.session_id)
          end
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
        self.write_response(request, 204, {"Allow" => "OPTIONS, POST", "Access-Control-Max-Age" => "2000000", "Cache-Control" => "public, max-age=#{year}", "Expires" => time.gmtime.to_s, "Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true"}, "") { |response| response.set_session_id(request.session_id) }
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :xhr_send]

      # Handler.
      def handle(request)
        match = request.path_info.match(self.class.prefix)
        session_id = match[1]
        session = self.connection.sessions[session_id]
        if session
          session.receive_message(request.data.read)

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
          self.write_response(request, 204, {"Content-Type" => CONTENT_TYPES[:plain], "Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true"}, "") { |response| response.set_session_id(request.session_id) }
        else
          self.write_response(request, 404, {"Content-Type" => CONTENT_TYPES[:plain]}, "Session is not open!") { |response| response.set_session_id(request.session_id) }
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
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
        match = request.path_info.match(self.class.prefix)
        session_id = match[1]

        response = self.response(request, 200, {"Content-Type" => CONTENT_TYPES[:javascript], "Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true"}) { |response| response.set_session_id(request.session_id) }
        response.write_head

        # IE requires 2KB prefix:
        # http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
        preamble = "h" * 2048 + "\n"
        self.try_timer_if_valid(request, response, preamble)
      end

      def format_frame(body)
        "#{body}\n"
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
