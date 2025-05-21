# frozen_string_literal: true

module Report
  module Random
    module_function

    def step_gap_size(source, opts: {})
      "Calculating gap size with source: #{source} and options: #{opts}"
    end
  end

  module TableExpression
    class Datum
      # @param table [Arel::Table] The table to use for the CTE
      # @param cte [Arel::Nodes::As] The CTE node
      # @param depends_on [Array<Symbol>] The dependencies for the CTE
      def initialize(table, cte, dependencies = [])
        @table = table
        @cte = cte
        @dependencies = dependencies
      end
      attr_reader :table, :cte, :dependencies
    end

  module Pipeline
    module_function

    def new_pipeline_definition
      pipeline = {
        shared_options: nil,
        prefix_tables: nil,
        context_module: nil,
        steps: []
      }
    end

    def pipeline_definition
      pipeline = {
        shared_options: 'coverage_options',
        prefix_tables: 'coverage',
        context_module: Report::Random,
        steps: [
          { type: :cte, method: :step_gap_size, args: ['time_series_options'] }
        ]
      }
    end

    # create or extend a collection
    def process(definition, initial_collection = nil)
      opts, mod, pipeline = definition.values_at(:shared_options, :context_module, :steps)
      inital_colledtion ||= Report::Expression::Collection.new

      pipeline.each_with_object(collection) do |current_step, collection|
        method = current_step[:method]
        valid_module? mod
        method_exist? mod, method
        collection[method] = mod.send(*instructions(current_step), opts: opts)
      end
      collection
    end

    def valid_module?(context_module)
      raise ArgumentError, 'context_module must be a module' unless context_module.is_a?(Module)
    end

    def method_exist?(mod, method_name)
      raise NoMethodError, "Method #{method_name} not found in #{mod}" unless mod.respond_to?(method_name)
    end

    def send_to(context_module, &)
      context_module.send(&)
    end

    def instructions(current_step)
      current_step.values_at(:method, :dependencies, :args).flatten.compact
    end
  end
end
