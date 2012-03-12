# encoding: utf-8

require "faye/websocket"

class Thin::Request
  WEBSOCKET_RECEIVE_CALLBACK = 'websocket.receive_callback'.freeze
  GET = 'GET'.freeze

  def websocket?
    @env['REQUEST_METHOD'] == GET and
    @env['HTTP_CONNECTION'] and
    @env['HTTP_CONNECTION'].split(/\s*,\s*/).include?('Upgrade') and
    ['WebSocket', 'websocket'].include?(@env['HTTP_UPGRADE'])
  end
end
