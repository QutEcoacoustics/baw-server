# frozen_string_literal: true

require 'liquid'

module BawWorkers
  module BatchAnalysis
    module CommandTemplater
      # Wraps time-like values to provide ISO8601 output in Liquid templates
      # without monkey patching Liquid internals globally.
      class TimeDrop < ::Liquid::Drop
        def initialize(time)
          super()
          @time = time
        end

        def to_s
          @time.iso8601
        end

        def strftime(format)
          @time.strftime(format)
        end
      end
    end
  end
end
