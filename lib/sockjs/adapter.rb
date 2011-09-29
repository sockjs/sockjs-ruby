# encoding: utf-8

module SockJS
  class Adapter
    class << self
      attr_accessor :prefix, :method, :filters, :subclasses
    end

    self.method     ||= "GET"
    self.subclasses ||= Array.new
    self.filters    ||= Array.new

    def self.handler(prefix, method)
      self.subclasses.find do |handler|
        handler.prefix == prefix && handler.method == method
      end
    end

    def self.inherited(subclass)
      @subclasses << subclass
      subclass.filters = Array.new
    end
  end
end
