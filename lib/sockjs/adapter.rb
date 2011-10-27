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
        handler.prefix === prefix && handler.method == method
      end
    end

    def self.inherited(subclass)
      Adapter.subclasses << subclass
      subclass.filters = Array.new

      subclass.method  = self.method
      subclass.prefix  = self.prefix
      subclass.filters = self.filters
    end

    # Instance methods.
    attr_reader :connection, :options
    def initialize(connection, options)
      @connection, @options = connection, options
    end
  end
end
