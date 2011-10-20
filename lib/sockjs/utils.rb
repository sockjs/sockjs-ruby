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
      @hash.each.reduce(0) do |already_waited, (execution_time_in_ms, data)|
        seconds_per_iteration = timer do
          execution_time = execution_time_in_ms / 1000.0

          sleep execution_time - already_waited
          puts block.call(data)
        end

        already_waited + seconds_per_iteration
      end
    end

    protected
    def timer(&block)
      - (Time.now.to_f.tap(&block) - Time.now.to_f)
    end
  end
end
