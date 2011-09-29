# encoding: utf-8

require_relative "../adapter"

# ['GET', p('/iframe[0-9-.a-z_]*.html'), ['iframe', 'cache_for', 'expose']],
module SockJS
  module Adapters
    class IFrame < Adapter
      # Settings.
      self.prefix  = /iframe[0-9-.a-z_]*.html/
      self.method  = "GET"
      self.filters = [:iframe, :cache_for, :expose]

      # Handler.
      def self.handle(env)
        raise NotImplementedError.new
      end
    end
  end
end
