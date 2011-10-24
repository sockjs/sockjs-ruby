# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters

    # This is the receiver.
    class JSONP < Adapter
      # Settings.
      self.prefix  = "jsonp"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :jsonp]

      # Handler.
      def handle(env, &block)
        qs = env["QUERY_STRING"].split("=").each_slice(2).reduce(Hash.new) do |buffer, pair|
          buffer.merge(pair.first => pair.last)
        end

        callback = qs["c"] || qs["callback"]

        if callback
          # session = transport.Session.bySessionIdOrNew(req.session, req.sockjs_server)
          # session.register( new JsonpReceiver(res, req.sockjs_server.options, callback) )

          [200, {"Content-Type" => "application/javascript; charset=UTF-8"}, Array.new]
        else
          body = "You have to specify 'callback' through the query string!"
          [500, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
        end
      end

      def self.send_frame(payload)
        # Yes, JSONed twice, there isn't a a better way, we must pass
        # a string back, and the script, will be evaled() by the browser.
        super(@callback + "(" + JSON.stringify(payload) + ");\r\n")
      end
    end

    # This is the sender.
    class JSONPSend < Adapter
      # Settings.
      self.prefix  = "jsonp_send"
      self.method  = "POST"
      self.filters = [:h_sid, :expect_form, :jsonp_send]

      # Handler.
      def handle(env, &block)
        if query
          data = JSON.parse(query)

          # jsonp = transport.Session.bySessionId(req.session)
          # if jsonp is null
          #     throw {status: 404}
          # for message in d
          #     jsonp.didMessage(message)

          [200, ["Content-Length" => "2"], ["ok"]]
        else
          body = "Payload expected!"
          [500, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
        end
      end
    end
  end
end
