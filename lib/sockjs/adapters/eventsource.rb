# encoding: utf-8

require_relative "../adapter"

module SockJS
  module Adapters
    class EventSource < Adapter
      # Settings.
      self.prefix  = "eventsource"
      self.method  = "GET"
      self.filters = [:h_sid, :h_no_cache, :eventsource]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
