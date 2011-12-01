# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters

    # This is the receiver.
    class JSONP < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp$/
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :jsonp]

      # Handler.
      def handle(request)
        if request.callback
          match = request.path_info.match(self.class.prefix)
          if session = self.connection.sessions[match[1]]
            body = self.send_frame(request.callback, session.process_buffer)

            unless body.respond_to?(:bytesize)
              raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
            end

            self.write_response(request, 200, {"Content-Type" => CONTENT_TYPES[:plain]}, body)
          else
            session = self.connection.create_session(match[1])
            body = self.send_frame(request.callback, session.open!.chomp)

            self.write_response(request, 200, {"Content-Type" => CONTENT_TYPES[:javascript], "Access-Control-Allow-Origin" => request.origin, "Access-Control-Allow-Credentials" => "true", "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"}, body) { |response| response.set_session_id(request.session_id) }
          end
        else
          body = '"callback" parameter required'
          self.write_response(request, 500, {"Content-Type" => CONTENT_TYPES[:html]}, body)
        end
      end

      def send_frame(callback_function, payload)
        # Yes, JSONed twice, there isn't a better way, we must pass
        # a string back, and the script, will be evaled() by the browser.
        "#{callback_function}(#{payload.chomp.to_json});\r\n"
      end
    end

    # This is the sender.
    class JSONPSend < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :expect_form, :jsonp_send]

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

              data = data.first.last
            else
              data = raw_form_data
            end

            session.receive_message(data)

            self.write_response(request, 200, Hash.new, "ok") do |response|
              response.set_session_id(request.session_id)
            end
          else
            self.write_response(request, 404, {"Content-Type" => CONTENT_TYPES[:plain]}, "Session is not open!") { |response| response.set_session_id(request.session_id) }
          end
        else
          self.write_response(request, 500, {"Content-Type" => CONTENT_TYPES[:html]}, "Payload expected!")
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end
    end
  end
end
