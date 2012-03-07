# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports

    # This is the receiver.
    class JSONP < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp$/
      self.method  = "GET"

      attr_accessor :callback_function

      # Handler.
      def handle(request)
        if request.callback
          match = request.path_info.match(self.class.prefix)
          self.callback_function = request.callback

          if session = self.connection.sessions[match[1]]
            respond(request, 200) do |response, session|
              response.set_content_type(:plain)

              body = self.format_frame(session.process_buffer)

              # This is very stupid ... session.close in app already sent the frame.
              # TODO: the same issue is surely in the other transports as well.
              unless session.closing?
                response.write(body)
              end
            end
          else
            respond(request, 200, session: :create) do |response, session|
              response.set_content_type(:javascript)
              response.set_access_control(request.origin)
              response.set_no_cache
              response.set_session_id(request.session_id)
              # response.write(body)
              p [:body, response.body.instance_variable_get(:@status)]

              session.open!(request.callback)
              p [:body, response.body.instance_variable_get(:@status)]
            end
          end
        else
          respond(request, 500) do |response|
            response.set_content_type(:html)
            response.write('"callback" parameter required')
          end
        end
      end

      def format_frame(payload)
        raise TypeError.new if payload.nil?

        # Yes, JSONed twice, there isn't a better way, we must pass
        # a string back, and the script, will be evaled() by the browser.
        "#{self.callback_function}(#{payload.chomp.to_json});\r\n"
      end
    end

    # This is the sender.
    class JSONPSend < Transport
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp_send$/
      self.method  = "POST"

      # Handler.
      def handle(request)
        if request.content_type == "application/x-www-form-urlencoded"
          self.handle_form_data(request)
        else
          self.handle_raw_data(request)
        end
      rescue SockJS::HttpError => error
        respond(request, 500) do |response|
          response.set_content_type(:html)
          response.write(error.message)
        end
      end

      def handle_form_data(request)
        raw_data = request.data.read || empty_payload
        data = URI.decode_www_form(raw_data)

        # It always has to be d=something.
        if data && data.first && data.first.first == "d"
          data = data.first.last
          self.handle_clean_data(request, data)
        else
          empty_payload
        end
      end

      def handle_raw_data(request)
        raw_data = request.data.read
        if raw_data && raw_data != ""
          self.handle_clean_data(request, raw_data)
        else
          empty_payload
        end
      end

      def handle_clean_data(request, data)
        match = request.path_info.match(self.class.prefix)
        session_id = match[1]
        session = self.connection.sessions[session_id]
        if session
          session.receive_message(request, data)

          respond(request, 200) do |response|
            response.set_content_type(:plain)
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
      end

      def empty_payload
        raise SockJS::HttpError.new("Payload expected.")
      end
    end
  end
end
