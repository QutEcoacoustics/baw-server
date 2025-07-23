# frozen_string_literal: true

module Report
  module Cte
    # Context for select block evaluation.
    # Exposes dependency tables and options as methods.
    class SelectContext
      attr_reader :options

      def initialize(dependencies, options)
        @options = options
        dependencies.each do |sym, table|
          define_singleton_method(sym) { table }
        end
      end
    end
  end
end
