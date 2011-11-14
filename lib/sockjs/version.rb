# encoding: utf-8

module SockJS
  # PROTOCOL_VERSION is SockJS protocol version used,
  # whereas VERSION is version of the gem. They are
  # currently the same, however this is NOT guaranteed
  # to be true in the future!
  PROTOCOL_VERSION ||= VERSION ||= "0.1"
end
