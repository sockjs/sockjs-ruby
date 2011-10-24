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
      def self.handle(env, options, sessions)
        match = env["PATH_INFO"].match(self.prefix)
        data  = sessions[match[1]]
        if data
          [200, {"Content-Type" => "text/plain", "Content-Length" => data.bytesize.to_s},  [data]]
        else
          [200, {"Content-Type" => "text/plain", "Content-Length" => "2"},  [Protocol::CLOSE_FRAME]]
        end
      end
    end

    class XHROptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def self.handle(env, options, sessions)
        [204, {"Allow" => "OPTIONS, POST", "Access-Control-Max-Age" => 1}, Array.new]
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :xhr_send]

      # Handler.
      def self.handle(env, options, sessions)
        match = env["PATH_INFO"].match(self.prefix)
        session_id = match[1]
        sessions[session_id] = Protocol.array_frame(env["rack.input"].read)
        [204, {}, Array.new]
      end
    end

    class XHRSendOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def self.handle(env, options, sessions)
        match = env["PATH_INFO"].match(self.prefix)
        p session_id = match[1]
        raise NotImplementedError.new
      end
    end

    class XHRStreamingPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :xhr_streaming]

      # Handler.
      def self.handle(env, options, sessions)
        raise NotImplementedError.new
      end
    end

    class XHRStreamingOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def self.handle(env, options, sessions)
        raise NotImplementedError.new
      end
    end
  end
end
