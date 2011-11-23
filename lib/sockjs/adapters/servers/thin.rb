# encoding: utf-8

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
    end
  end
end
