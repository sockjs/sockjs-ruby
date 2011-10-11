# encoding: utf-8

module SockJS
  class Timeoutable
    # Timeoutable.new(0 => "first chunk", 5 => "second chunk")
    def initialize(hash = Hash.new)
      @hash = hash
    end

    # def each(&block)
    #   wait_for = @hash.reduce(0) do |wait_for, (ms, data)|
    #     EM.add_timer(ms / 1000.0) do
    #       block.call(data)
    #     end
    #
    #     wait_for + ms
    #   end
    #
    #   sleep (wait_for + 500) / 1000.0 # TODO: How to do it in a non-blocking fashion?
    # end

    # TODO: Figure out how to make it EM-compatible (see above).
    def each(&block)
      @hash.each do |ms, data|
        sleep ms / 1000.0
        block.call(data)
      end
    end
  end
end
