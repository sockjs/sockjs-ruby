# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports

    # This is the receiver.
    class JSONP < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp$/
      self.method  = "GET"

      # Handler.
      def handle(request)
        if request.callback
          match = request.path_info.match(self.class.prefix)
          if session = self.connection.sessions[match[1]]
            body = self.send_frame(request.callback, session.process_buffer)

            unless body.respond_to?(:bytesize)
              raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
            end

            respond(request, 200) do |response|
              response.set_content_type(:plain)
              response.write(body)
            end
          else
            self.create_session(request.path_info)

            respond(request, 200, session: :create) do |response, session|
              response.set_content_type(:javascript)
              response.set_access_control(request.origin)
              response.set_no_cache
              # response.write(body)

              session.open!(request.callback)
            end
          end
        else
          respond(request, 500) do |response|
            response.set_content_type(:html)
            response.write('"callback" parameter required')
          end
        end
      end

      def format_frame(callback_function, payload)
        raise TypeError.new if payload.nil?

        # Yes, JSONed twice, there isn't a better way, we must pass
        # a string back, and the script, will be evaled() by the browser.
        "#{callback_function}(#{payload.chomp.to_json});\r\n"
      end
    end

    # This is the sender.
    class JSONPSend < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp_send$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        if raw_form_data = request.data.read
          match = request.path_info.match(self.class.prefix)
          session_id = match[1]
          session = self.connection.sessions[session_id]
          if session

            if request.content_type == "application/x-www-form-urlencoded"
              data = URI.decode_www_form(raw_form_data)

              if data.nil? || data.first.nil? || data.first.last.nil?
                raise SockJS::HttpError.new("Payload expected.")
              end

              # It always has to be d=something.
              if data.first.first == "d"
                data = data.first.last
              else
                data = ""
              end
            else
              data = raw_form_data
            end

            session.receive_message(data)

            respond(request, 200) do |response|
              response.set_session_id(request.session_id)
              response.write("ok")
            end
          else
            respond(request, 404) do |response|
              response.set_content_type(:plain)
              response.set_session_id(request.session_id)
              response.write("Session is not open!")
            end
          end
        else
          respond(request, 500) do |response|
            response.set_content_type(:html)
            response.write("Payload expected!")
          end
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end
    end
  end
end
