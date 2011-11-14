# encoding: utf-8

require "uri"

require_relative "../adapter"

module SockJS
  module Adapters

    # This is the receiver.
    class JSONP < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/jsonp$/
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :jsonp]

      # Handler.
      def handle(env)
        qs = env["QUERY_STRING"].split("=").each_slice(2).reduce(Hash.new) do |buffer, pair|
          buffer.merge(pair.first => pair.last)
        end

        callback = qs["c"] || qs["callback"]

        if callback
          callback = URI.unescape(callback)

          match = env["PATH_INFO"].match(self.class.prefix)
          if session = self.connection.sessions[match[1]]
            body = self.send_frame(callback, session.process_buffer)

            unless body.respond_to?(:bytesize)
              raise TypeError, "Block has to return a string or a string-like object responding to #bytesize, but instead an object of #{body.class} class has been returned (object: #{body.inspect})."
            end

            self.response.write_head(200, {"Content-Type" => CONTENT_TYPES[:plain], "Content-Length" => body.bytesize.to_s})
            self.response.finish(body)
          else
            session = self.connection.create_session(match[1])
            body = self.send_frame(callback, session.open!.chomp)
            origin = env["HTTP_ORIGIN"] || "*"
            jsessionid = Rack::Request.new(env).cookies["JSESSIONID"]

            self.response.write_head(200, {"Content-Type" => CONTENT_TYPES[:javascript], "Content-Length" => body.bytesize.to_s, "Set-Cookie" => "JSESSIONID=#{jsessionid || "dummy"}; path=/", "Access-Control-Allow-Origin" => origin, "Access-Control-Allow-Credentials" => "true", "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0"})
            self.response.finish(body)
          end
        else
          body = '"callback" parameter required'
          self.response.write_head(500, {"Content-Type" => CONTENT_TYPES[:html], "Content-Length" => body.bytesize.to_s})
          self.response.finish(body)
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
      def handle(env)
        if raw_form_data = env["rack.input"].read
          match = env["PATH_INFO"].match(self.class.prefix)
          session_id = match[1]
          session = self.connection.sessions[session_id]
          if session

            if env["CONTENT_TYPE"] == "application/x-www-form-urlencoded"
              data = URI.decode_www_form(raw_form_data)

              if data.nil? || data.first.nil? || data.first.last.nil?
                raise SockJS::HttpError.new("Payload expected.")
              end

              data = data.first.last
            else
              data = raw_form_data
            end

            session.receive_message(data)

            jsessionid = Rack::Request.new(env).cookies["JSESSIONID"]
            self.response.write_head(200, {"Content-Length" => "2", "Set-Cookie" => "JSESSIONID=#{jsessionid || "dummy"}; path=/"})
            self.response.finish("ok")
          else
            body = "Session is not open!"
            self.response.write_head(404, {"Content-Type" => CONTENT_TYPES[:plain], "Content-Length" => body.bytesize.to_s, "Set-Cookie" => "JSESSIONID=dummy; path=/"})
            self.response.finish(body)
          end
        else
          body = "Payload expected!"
          self.response.write_head(500, {"Content-Type" => CONTENT_TYPES[:html], "Content-Length" => body.bytesize.to_s})
          self.response.finish(body)
        end
      rescue SockJS::HttpError => error
        error.to_response
      end
    end
  end
end
