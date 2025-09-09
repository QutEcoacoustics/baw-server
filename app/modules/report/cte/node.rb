# frozen_string_literal: true

module Report
  module Cte
    class Node
      attr_reader :name, :options

      def initialize(name, suffix: nil, select: nil, dependencies: {}, options: {}, &block)
        assert_proc_given(select || block)

        @name = TableName.new(name, suffix)
        @options = options

        @select_proc = select || block
        @evaluate_select_proc = NodeEvaluator.new

        @passed_depedencies = dependencies
        @dependency_initialiser = Dependencies::Initialiser.new(cascade_attributes: cascade_attributes.call)
        @resolve_graph = Dependencies::TopologicalSort.new
      end

      def assert_proc_given(proc_given)
        return if proc_given

        raise ArgumentError, 'Select or a block is required to initialize a Node'
      end

      def cascade_attributes = -> { { suffix: name.suffix, options: options } }

      def arel_table = @arel_table ||= Arel::Table.new(@name.table_name)

      def arel_node = @arel_node ||= arel_select.as(@name.table_name)

      def arel_select
        @arel_select ||= @evaluate_select_proc.using(method_definitions).evaluate(@select_block)
      end

      def method_definitions
        dependencies
          .transform_values(&:arel_table)
          .merge(options: options)
          .merge(name: @name.table_name)
      end

      def dependencies
        @dependencies ||= @dependency_initialiser.call(@passed_depedencies)
      end

      def collect(registry = {})
        without_self(resolve_graph(registry))
      end

      def resolve_graph(registry = {})
        @registry ||= registry
        @resolve_graph.traverse(self, @registry)
      end

      def without_self(graph)
        graph.reject { |node| node.name == name }
      end

      # Generates the Arel representation of this Cte node as a query, including
      # all its dependencies.
      #
      # This is like getting the WITH clause that contains all dependency Ctes,
      # followed by the main select statement from the current node. If there are
      # no dependencies, we just return the select statement.
      #
      # @param registry [Hash] Registry for dependency injection
      # @return [Arel::SelectManager]
      def to_arel(registry = {})
        # otherwise the select manager is modified by #with
        select_expr = select_manager.dup
        return select_expr if dependencies.empty?

        dependency_arel_nodes = collect(registry).map(&:node)
        select_expr.with(dependency_arel_nodes)
      end

      def to_sql(registry = {})
        to_arel(registry).to_sql
      end

      # Convenience method to execute the Cte query against the database
      def execute(registry = {})
        ActiveRecord::Base.connection.execute(to_sql(registry))
      end

      # the default inspect gets unruly with the recursive structure
      def pretty_print(pp)
        pp.object_group(self) do
          pp.seplist(attributes_for_inspect) do |pair| # Loops over your specified [key, value] pairs
            k, v = pair
            pp.breakable ' '
            pp.text "#{k}=" # Uses the provided key directly (e.g., :name becomes "name=")
            pp.pp v
          end
        end
      end

      def attributes_for_inspect
        [
          [:name, name],
          [:passed_dependencies, @passed_dependencies],
          [:dependencies, @dependencies || 'nil || unevaluated'],
          [:options, options]
        ]
      end
    end
  end
end
