# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class XHRPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        respond(request, 200) do |response, session|
          if session
            body = session.process_buffer

            unless body.respond_to?(:bytesize)
              raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
            end

            response.set_header("Content-Type", CONTENT_TYPES[:plain])
            response.finish(body)
          else
            # TODO: refactor this.
            match = request.path_info.match(self.class.prefix)
            session = self.connection.create_session(match[1], self)

            response.set_header("Content-Type", CONTENT_TYPES[:javascript])
            response.set_header("Access-Control-Allow-Origin", request.origin)
            response.set_header("Access-Control-Allow-Credentials", "true")
            response.set_session_id(request.session_id)
            session.open!
            response.finish
          end
        end
      end
    end

    class XHROptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"

      # Handler.
      def handle(request)
        year = 31536000
        time = Time.now + year

        respond(request, 204) do |response, session|
          response.set_header("Allow", "OPTIONS, POST")
          response.set_header("Access-Control-Max-Age", "2000000")
          response.set_header("Cache-Control", "public, max-age=#{year}")
          response.set_header("Expires", time.gmtime.to_s)
          response.set_header("Access-Control-Allow-Origin", request.origin)
          response.set_header("Access-Control-Allow-Credentials", "true")

          response.finish
        end
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        respond(request, 204, set_session_id: true) do |response, session|
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
            response.set_header("Content-Type", CONTENT_TYPES[:plain])
            response.set_header("Access-Control-Allow-Origin", request.origin)
            response.set_header("Access-Control-Allow-Credentials", "true")
            response.finish
          else
            self.error(404, :plain, "Session is not open!")
          end
        end

      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end
    end

    class XHRSendOptions < XHROptions
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "OPTIONS"
    end

    class XHRStreamingPost < Adapter
      # Settings.
      self.prefix        = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method        = "POST"
      self.session_class = Session

      # Handler.
      def handle(request)
        respond(request, 200, set_session_id: true) do |response, session|
          response.set_header("Content-Type", CONTENT_TYPES[:javascript])
          response.set_header("Access-Control-Allow-Origin", request.origin)
          response.set_header("Access-Control-Allow-Credentials", "true")
          response.write_head

          # IE requires 2KB prefix:
          # http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
          preamble = "h" * 2048 + "\n"
          self.try_timer_if_valid(request, response, preamble)
        end
      end

      def format_frame(body)
        "#{body}\n"
      end

      def send(*messages)
        messages.each do |message|
          @response.write(message)
        end
      end
    end

    class XHRStreamingOptions < XHROptions
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "OPTIONS"
    end
  end
end
