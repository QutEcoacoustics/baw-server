# frozen_string_literal: true

module Report
  module Cte
    # Represent a Cte node in a dependency graph.
    #
    # This class should be subclassed to define templates for Cte nodes. See # `Cte::Dsl`.
    #
    # The idea is to lazily resolve attributes only when needed, including
    # dependencies and the select block, and memoizing the results to improve
    # performance. The class supports dependency injection via a registry,
    # options propagation for customizing behavior, and flexible select logic
    # via blocks.
    #
    # The registry and lazy graph resolution mean that Ctes in dependency
    # hierarchies can be automatically shared and re-used across queries. If you
    # need to reuse a query (a Cte + all its dependencies), but with different
    # logic applied (e.g. injecting a different set of options, or a different
    # select block), a node can be instantiated with a suffix. The suffix is
    # applied to the table name, and will propagate the suffix to all
    # uninstantiated dependencies when it is resolved.
    class Node
      extend Report::Cte::Dsl
      attr_reader :options
      attr_accessor :name, :select_block

      # Initializes a new Cte node.
      #
      # @param name [Symbol] The name of the node.
      # @param dependencies [Array<Node|Class>] The Cte nodes this node depends on.
      # @param suffix [Symbol, nil] An optional suffix to append to the node name.
      # @param select [Arel::SelectManager, Arel::Nodes::SqlLiteral, nil] An Arel select statement.
      # @param options [Hash] A hash of options to be used by the select block.
      # @param block [Proc] A block that generates the select statement.
      def initialize(name,
                     dependencies: {},
                     suffix: nil,
                     options: {},
                     select: nil,
                     &block)
        @name = suffix ? :"#{name}_#{suffix}" : name.to_sym
        @initial_dependencies = Hash(dependencies)
        @suffix = suffix
        @select_block = block || validate_select(select)

        @options = default_options.merge(options)
      end

      # Default options for the node. Subclasses can define this to set their
      # own defaults.
      # @return [Hash]
      def default_options
        {}
      end

      # Return an Arel::Table for the Cte
      # We memoize the table to avoid redundant creation and ensure consistency.
      # @return [Arel::Table]
      def table
        @table ||= Arel::Table.new(@name)
      end

      # Create the Arel node representing the Cte
      # @return [Arel::Nodes::As]
      def node
        @node ||= select_manager.as(table.name)
      end

      # Returns `select` as an Arel::SelectManager.
      # @return [Arel::SelectManager]
      def select_manager
        if select.is_a?(Arel::SelectManager)
          select
        elsif select.is_a?(Arel::Nodes::SqlLiteral)
          Arel::SelectManager.new.project(select)
        else
          raise ArgumentError, "Unsupported select type: #{select.class.name} for node: #{name}"
        end
      end

      # Resolve the dependency nodes and memoize the result. Instantiates them
      # if they are classes, propagating options and suffix.
      #
      # @return [Array<Node>]
      def dependencies
        @dependencies ||= @initial_dependencies.transform_values { |dep|
          case dep
          in Node
            dep
          in Class => klass if klass <= Cte::Node
            klass.new(suffix: @suffix, options: @options)
          else
            raise ArgumentError,
              "Dependency must be a Node or subclass, got: #{dep.class.name} (#{dep.inspect})"
          end
        }
      end

      # Collect all nodes in the dependency graph, including self if `root` is
      # true (default), returning them in topological order. Supports dependency
      # injection of nodes via a registry; nodes in the registry will be used
      # instead of creating new instances.
      #
      # Note: When injecting a node, the key in the registry must match the name
      # that a node *will have*, in the case of any suffix being applied.
      #
      # @param registry [Hash] Hash mapping node names to instances for injection
      # @param root [Boolean] Whether to include the current node in the result
      # @return [Array<Node>]
      def collect(registry = {}, root: true)
        @registry ||= registry
        result = resolve_dependency_graph(Set.new, [], @registry)
        result.reject! { |node| node.name == name } unless root
        result
      end

      # Resolve the dependency graph using topological sort. The idea is to
      # traverse dependencies in a depth-first manner, ensuring Ctes are defined
      # before they are referenced in the SQL.
      #
      # The shared registry caches resolved nodes, allowing nodes to be re-used
      # rather than re-instantiated.
      #
      # @param visited [Set] The set of node names already visited
      # @param result [Array] The topologically sorted list of nodes.
      # @param registry [Hash] The registry cache
      # @return [Array<Node>]
      def resolve_dependency_graph(visited = Set.new, result = [], registry = {})
        # first use the registry to fetch an existing node with the same name.
        # otherwise continue to resolve self.
        node_to_resolve = registry.fetch(name, self)
        registry[node_to_resolve.name] = node_to_resolve

        return result if visited.include?(node_to_resolve.name)

        visited.add(node_to_resolve.name)

        # Recursively resolve dependencies of the current `node_to_resolve`.
        # Calling #dependencies here returns the memoized array of dependencies
        # for the node being resolved.
        node_to_resolve.dependencies.values.each do |dep|
          dep_instance = registry.fetch(dep.name, dep)
          dep_instance.resolve_dependency_graph(visited, result, registry)
        end

        result << node_to_resolve unless result.include?(node_to_resolve)
        result
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
        select_expr = select_manager
        return select_expr if dependencies.empty?

        # Collect all dependency nodes (but not self, so root is false) and get
        # their Arel node representations.
        dependency_arel_nodes = collect(registry, root: false).map(&:node)

        select_expr.with(dependency_arel_nodes)
      end

      def to_sql(registry = {})
        to_arel(registry).to_sql
      end

      # Convenience method to execute the Cte query against the database
      def execute(registry = {})
        ActiveRecord::Base.connection.execute(to_sql(registry))
      end

      private

      attr_reader :suffix

      def validate_select(select)
        raise ArgumentError, 'Either a block or select must be provided' if select.nil?
        raise ArgumentError, "Select must be a Proc, got: #{select.class.name}" unless select.is_a?(Proc)

        select
      end

      # Generates the Arel select statement for this Cte by evaluating the stored
      # block. The result is memoized.
      # @return [Arel::SelectManager, Arel::Nodes::SqlLiteral]
      # @raise [ArgumentError] If no block was provided
      def select
        @select ||= if @select_block
                      call_block_with_dependencies
                    else
                      raise ArgumentError, "(node: #{@name}) requires a select block"
                    end
      end

      # Execute the block within a context that provides access to the
      # Arel::Tables of any dependecies, and the options hash.
      def call_block_with_dependencies
        resolved_deps = dependencies.transform_values(&:table)
        context = Report::Cte::SelectContext.new(resolved_deps, @options)
        context.instance_exec(&@select_block)
      rescue StandardError => e
        # If the block raises an error, we want to provide a clear message
        # indicating which node and block caused the issue.
        raise StandardError,
          "error while calling block: #{@block} for node: #{@name}\n#{e.message}\n}"
      end
    end
  end
end
