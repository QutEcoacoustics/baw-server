# frozen_string_literal: true

module Report
  module Cte
    class Pipeline
      def add_step(proc)
        @steps ||= []
        @steps << proc
        self
      end

      def execute(initial_value)
        @steps.reduce(initial_value) { |value, action| action.call(value) }
      end
    end
  end
end
