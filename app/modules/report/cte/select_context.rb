# frozen_string_literal: true

module Report
  module Cte
    # Context for select block evaluation.
    # Exposes dependency tables and options as methods.
    class SelectContext
      def self.execute_with_context(lambda_proc, dependencies, options = {})
        # Get the lambda's original binding
        original_binding = lambda_proc.binding

        # Inject methods into the binding's self
        dependencies.each do |name, table|
          original_binding.eval('self').define_singleton_method(name) { table }
        end
        original_binding.eval('self').define_singleton_method(:options) { options }

        lambda_proc.call
      end
    end
  end
end
