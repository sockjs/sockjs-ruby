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
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
        puts "\033[0;34;40m? SESSION #{match[1]} = #{connection.sessions[match[1]].inspect}\033[0m"

        if connection.status == :opened
          body = message_received(connection.sessions[match[1]])
          [200, {"Content-Type" => "text/plain", "Content-Length" => body.bytesize.to_s}, [body]]
        else
          connection.open!(match[1])
          [200, {"Content-Type" => "text/plain", "Content-Length" => "2"}, [Protocol::OPEN_FRAME]]
        end
      end
    end

    class XHROptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        [204, {"Allow" => "OPTIONS, POST", "Access-Control-Max-Age" => 1}, Array.new]
      end
    end

    class XHRSendPost < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "POST"
      self.filters = [:h_sid, :xhr_cors, :expect_xhr, :xhr_send]

      # Handler.
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
        session_id = match[1]
        connection.sessions[session_id] = Protocol.array_frame(env["rack.input"].read)
        puts "\033[0;32;40m~~> SESSION #{session_id} = #{connection.sessions[session_id].inspect}\033[0m" ###
        [204, Hash.new, Array.new]
      end
    end

    class XHRSendOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_send$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        match = env["PATH_INFO"].match(self.class.prefix)
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
      def handle(env)
        raise NotImplementedError.new
      end
    end

    class XHRStreamingOptions < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/xhr_streaming$/
      self.method  = "OPTIONS"
      self.filters = [:h_sid, :xhr_cors, :cache_for, :xhr_options, :expose]

      # Handler.
      def handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
