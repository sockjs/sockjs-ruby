# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class JSONP < Adapter
      # Settings.
      self.prefix  = "jsonp"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :jsonp]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end

    class JSONPSend < Adapter
      # Settings.
      self.prefix  = "jsonp_send"
      self.method  = "POST"
      self.filters = [:h_sid, :expect_form, :jsonp_send]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
