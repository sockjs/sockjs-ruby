# encoding: utf-8

require "forwardable"
require "sockjs/faye"
require "sockjs/transport"

module SockJS
  module Transports
    module WSDebuggingMixin
      def send_data(*args)
        if args.length == 1
          data = args.first
        else
          data = fix_buggy_input(*args)
        end

        if $DEBUG
          puts "~> WS#send #{data.inspect} #{caller[0..2].map { |item| item.sub(Dir.pwd + "/lib/", "") }.inspect}"
        else
          puts "~> WS#send #{data.inspect}"
        end

        super(data)
      end

      def fix_buggy_input(*args)
        data = 'c[3000,"Go away!"]'
        puts "! Incorrect input: #{args.inspect}, changing to #{data} for now"
        return data
      end
    end


    class RawWebSocket < Transport
      # Settings.
      self.prefix = /^websocket$/
      self.method = "GET"

      # Handler.
      def handle(request)
      end
    end
  end
end
