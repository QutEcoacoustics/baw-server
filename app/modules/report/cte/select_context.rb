# frozen_string_literal: true

module Report
  module Cte
    # Context for select block evaluation.
    # Exposes dependency tables and options as methods.
    # Exposes 'name' method (table_name) for the node name at time of evaluation - useful for dynamic field aliasing
    # E.g. project(field.as(name.to_s)) => SELECT field AS "table_name"
    #                                   => SELECT field AS "table_name_with_suffix"
    class SelectContext
      def self.execute_with_context(name, lambda_proc, dependencies, options = {})
        # Get the lambda's original binding
        original_binding = lambda_proc.binding

        # Inject methods into the binding's self
        dependencies.each do |name, table|
          original_binding.eval('self').define_singleton_method(name) { table }
        end
        original_binding.eval('self').define_singleton_method(:name) { name }
        original_binding.eval('self').define_singleton_method(:options) { options }

        lambda_proc.call
      end
    end
  end
end
