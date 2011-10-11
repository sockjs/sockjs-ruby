# encoding: utf-8

module SockJS
  class Timeoutable
    # Timeoutable.new(0 => "first chunk", 5 => "second chunk")
    def initialize(hash = Hash.new)
      @hash = hash
    end

    def each(&block)
      @hash.each do |ms, data|
        EM.add_timeout(ms) do
          block.call(data)
        end
      end
    end
  end
end
