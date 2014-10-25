module BawWorkers
  # Logs to more than one logger
  class MultiLogger

    def initialize(*targets)
      # from http://stackoverflow.com/a/18118055
      @targets = targets
    end

    %w(debug info warn error fatal unknown).each do |m|
      define_method(m) do |*args|
        @targets.map { |t| t.send(m, *args) }
      end
    end

  end
end