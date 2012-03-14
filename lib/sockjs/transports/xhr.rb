# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports
    class XHRPost < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        response(request, 200, session: :create) do |response, session|
          unless session.newly_created?
            response.set_content_type(:plain)
            session.process_buffer
          else
            response.set_content_type(:javascript)
            response.set_access_control(request.origin)
            response.set_session_id(request.session_id)

            session.open!
          end
        end
      end
    end

    class XHROptions < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"

      # Handler.
      def handle(request)
        response(request, 204) do |response|
          response.set_allow_options_post
          response.set_cache_control
          response.set_access_control(request.origin)
          response.set_session_id(request.session_id)
        end
      end
    end

    class XHRSendPost < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        response(request, 204, data: request.data.read) do |response, session|
          if session
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
            response.set_content_type(:plain)
            response.set_access_control(request.origin)
            response.set_session_id(request.session_id)
            response.write_head
          else
            # We have to use curly brackets, because of ... well
            # because of bulldozer really http://pastie.org/3540401
            raise SockJS::HttpError.new(404, "Session is not open!") { |response|
              response.set_session_id(request.session_id)
            }
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

    class XHRStreamingPost < Transport
      # Settings.
      self.prefix = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method = "POST"

      def session_class
        SockJS::Session
      end

      # Handler.
      def handle(request)
        response(request, 200, session: :create) do |response, session|
          response.set_content_type(:javascript)
          response.set_access_control(request.origin)
          response.set_session_id(request.session_id)
          response.write_head

          # IE requires 2KB prefix:
          # http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
          preamble = "h" * 2048 + "\n"
          response.write(preamble)

          if session.newly_created?
            session.open!
          end

          session.wait(response)
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
