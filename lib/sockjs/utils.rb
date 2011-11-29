# encoding: utf-8

module SockJS
  class Timeoutable
    # Timeoutable.new(0 => "first chunk", 5 => "second chunk")
    def initialize(body, hash = Hash.new)
      @body, @hash = body, hash
    end

    def each(&block)
      @hash.each do |ms, data|
        EM.add_timer(ms / 1000.0) do
          block.call(data)
          if @hash.keys.last == ms
            @body.succeed
          end
        end
      end
    end
  end
end
