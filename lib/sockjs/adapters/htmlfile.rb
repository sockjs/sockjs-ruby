# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class HTMLFile < Adapter
      # Settings.
      self.prefix  = "htmlfile"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :htmlfile]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
