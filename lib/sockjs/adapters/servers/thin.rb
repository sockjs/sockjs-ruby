# encoding: utf-8

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
    end

    # This is just to make Rack happy.
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]
  end
end
