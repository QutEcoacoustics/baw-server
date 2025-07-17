# frozen_string_literal: true

# The Cte module provides a flexible framework for defining and resolving Common
# Table Expressions (CTEs) in SQL queries using Arel. The intent is to allow
# developers to define reusable CTE nodes with dependencies, default options,
# and custom select logic, while supporting dependency injection and topological
# sorting for complex query graphs. The module is designed to be highly
# flexible, allowing overrides for names, dependencies, and options,
module Cte
  # The Dsl module provides an interface for defining CTE nodes in a
  # factory-like way.
  module Dsl
    # Defines a new CTE node class with the specified table name and DSL block.
    # The block is evaluated in the context of the new class, allowing the use
    # of DSL methods like depends_on, default_options, and block.
    # @param table_name [Symbol] The default name for the CTE table
    # @param dsl_block [Proc] A block containing DSL method calls to configure the CTE
    # @return [Class] A new subclass of LazyCteNode
    def define_table(table_name, &dsl_block)
      klass = Class.new(Cte::LazyCteNode) do
        # store class-level configuration for table name, dependencies, options,
        # and select statement block, used to set the default values for
        # instances of this class.
        @_table_name = table_name
        @_depends_on = {}
        @_default_options = {}
        @_select_block = nil

        # class-level accessors for configuration
        class << self
          attr_accessor :_table_name, :_depends_on, :_default_options, :_select_block
        end

        # DSL method to define named dependencies for the CTE using keyword
        # arguments.
        #
        # Each key becomes an instance method in the select block's evaluation
        # context, that will return the dependency's Arel::Table. The key
        # functions only to provide a consistent interface for accessing a
        # dependency within the context of this specific CTE node's select
        # block, regardless of a dependency's actual state when it is resolved
        # (e.g. table names can change due to suffixes). It does not need to
        # match the name of the dependency node.
        #
        # @param dependencies [Hash{Symbol => Class, LazyCteNode}]
        def self.depends_on(**dependencies)
          @_depends_on = dependencies
        end

        # DSL method to set default options for the Cte
        # @param opts [Hash] default options
        # @param options_block [Proc] optional block for dsl style options
        def self.default_options(**opts, &options_block)
          @_default_options = options_block ? options_block.call : opts
        end

        # DSL method to define the select logic for the CTE.
        #
        # Instance methods will be available in the evaluation context of the
        # block for accessing a node's options hash (#options) and the
        # Arel::Tables of any dependencies (#{dependency_key}).
        #
        # @param blk [Proc] Block that returns an Arel::SelectManager or
        # Arel::Nodes::SqlLiteral
        def self.select(&blk)
          @_select_block = blk
        end

        # Instance method to access the class-level default_options. This method
        # is used in the super class to merge the default options with any
        # options passed during initialization.
        define_method(:default_options) do
          self.class._default_options
        end

        # Initialize instances with class-level defaults. We override initialize
        # to use the stored defaults while still allowing overrides for name,
        # dependencies, suffix, and the select statement (block). This provides
        # flexibility for instantiation while maintaining the class-level
        # configuration.
        define_method(:initialize) do |name = self.class._table_name, dependencies: self.class._depends_on, suffix: nil, options: {}, &block|
          block = self.class._select_block if block.nil? # Use class-level select block if not provided
          super(name, dependencies: dependencies, suffix: suffix, options: options, &block)
        end
      end

      # Evaluate the provided DSL block in the context of this class
      # This allows the DSL methods to configure the class directly.
      klass.instance_eval(&dsl_block) if dsl_block
      klass
    end

    module_function :define_table
  end

  # LazyCteNode is the core class for representing a CTE node in a dependency
  # graph. The idea is to lazily resolve attributes only when they are needed,
  # including dependencies and the select block, and memoizing the results to
  # improve performance. The class supports dependency injection via a registry,
  # options propagation for customizing behavior, and flexible select logic via
  # blocks.
  #
  # The registry and lazy graph resolution means that CTEs in dependency
  # hierarchies can be automatically shared and re-used across queries. If you
  # need to reuse a query (A CTE + all its dependencies), but with different
  # logic applied (e.g. injecting a different set of options, or a different
  # select block), a node can be instantiated with a suffix. The suffix is
  # applied to the table name, and will propagate the suffix to all
  # uninstantiated dependencies when it is resolved.
  class LazyCteNode
    extend Cte::Dsl
    attr_reader :block, :options
    attr_accessor :name

    # Initializes a new CTE node.
    #
    # @param name [Symbol] The name of the CTE.
    # @param dependencies [Array<LazyCteNode|Class>] The CTE nodes this node depends on.
    # @param suffix [Symbol, nil] An optional suffix to append to the CTE name.
    # @param select [Arel::SelectManager, Arel::Nodes::SqlLiteral, nil] An Arel select statement.
    # @param options [Hash] A hash of options to be used by the select block.
    # @param block [Proc] A block that generates the select statement.
    def initialize(name,
                   dependencies: {},
                   suffix: nil,
                   options: {},
                   &block)
      @name = suffix ? :"#{name}_#{suffix}" : name.to_sym
      @initial_dependencies = Hash(dependencies)
      @suffix = suffix
      @select_block = block

      @options = default_options.merge(options)
    end

    # Default options for the node. Subclasses can define this to set their
    # own defaults.
    # @return [Hash]
    def default_options
      {}
    end

    # Return an Arel::Table for the CTE
    # We memoize the table to avoid redundant creation and ensure consistency.
    # @return [Arel::Table]
    def table
      @table ||= Arel::Table.new(@name)
    end

    # Generates the Arel select statement for this CTE by evaluating the stored
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
      context = Cte::SelectContext.new(resolved_deps, @options)
      context.instance_eval(&@select_block)
    rescue StandardError
      # If the block raises an error, we want to provide a clear message
      # indicating which node and block caused the issue.
      raise StandardError, "error while calling block: #{@block} for node: #{@name}\n"

      # dependencies.map(&:table).then { |tables|
      #   tables = tables.first if tables.size == 1
      #   begin
      #     @block.call(dependencies: tables, options: @options)
      # rescue StandardError
      # Inspecting the @block for better tracing while debugging
      # raise StandardError, "error while calling block: #{@block} for node: #{@name}\n"
      # end
      # }
    end

    # Create the Arel node representing the CTE
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

    # Resolve the dependency nodes and memoize the result. Instantiates them if
    # they are classes, propagating options and suffix.
    #
    # @return [Array<LazyCteNode>]
    def dependencies
      @dependencies ||= @initial_dependencies.transform_values { |dep|
        case dep
        in LazyCteNode
          dep
        in Class => klass if klass <= Cte::LazyCteNode
          klass.new(suffix: @suffix, options: @options)
        else
          raise ArgumentError, "Dependency must be a LazyCteNode or subclass, got: #{dep.class.name} (#{dep.inspect})"
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
    # @return [Array<LazyCteNode>]
    def collect(registry = {}, root: true)
      @registry ||= registry
      result = resolve_dependency_graph(Set.new, [], @registry)
      result.reject! { |node| node.name == name } unless root
      result
    end

    # Resolve the dependency graph using topological sort. The idea is to
    # traverse dependencies in a depth-first manner, ensuring CTEs are defined
    # before they are referenced in the SQL.
    #
    # The shared registry caches resolved nodes, allowing nodes to be re-used
    # rather than re-instantiated.
    #
    # @param visited [Set] The set of node names already visited
    # @param result [Array] The topologically sorted list of nodes.
    # @param registry [Hash] The registry cache
    # @return [Array<LazyCteNode>]
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

    # Generates the Arel representation of this CTE node as a query, including
    # all its dependencies.
    #
    # This is like getting the WITH clause that contains all dependency CTEs,
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

    # Convenience method to execute the CTE query against the database
    def execute(registry = {})
      ActiveRecord::Base.connection.execute(to_sql(registry))
    end

    private

    attr_reader :suffix
  end

  # Provides a context for evaluating a select block with access to options and
  # dependencies, at the time of evaluation.
  # * note - I think this means constants that are in scope where the block is
  # defined will not be available in the context of the block which could be
  # confusing. have to check that
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

# =============================================================================
#
# Examples
#
# =============================================================================

# -- Example: Templating CTEs
TableA = Cte::Dsl.define_table :table_a do
  default_options alias: 'is_squanchy'

  select do
    event = AudioEvent.arel_table
    # accessing options directly in the select block
    event.project(event[:id], event[:is_reference].as(options[:alias]))
  end
end

p TableA.new.to_sql == %(SELECT "audio_events"."id", "audio_events"."is_reference" AS "is_squanchy" FROM "audio_events")

TableB = Cte::Dsl.define_table :table_b do
  depends_on table_a: TableA

  select do
    # accessing the table_a dependency table using its key as the method name
    table_a.project(table_a[:is_squanchy].count.as('count_of_squanchies'))
      .where(table_a[:is_squanchy].eq(true))
  end
end

p TableB.new.to_sql == %(WITH "table_a" AS (SELECT "audio_events"."id", "audio_events"."is_reference" AS "is_squanchy" FROM "audio_events") SELECT COUNT("table_a"."is_squanchy") AS "count_of_squanchies" FROM "table_a" WHERE "table_a"."is_squanchy" = TRUE)
TableB.new.execute

# -- Example: Overriding default options
table_a_instance = TableA.new(options: { alias: 'is_squanchy_2' })
p table_a_instance.to_sql == %(SELECT "audio_events"."id", "audio_events"."is_reference" AS "is_squanchy_2" FROM "audio_events")

# -- Example: Using the registry to inject the TableA instance.
registry = { table_a_instance.name => table_a_instance }

# The SQL for TableA has the column alias 'is_squanchy_2' from the injected instance, instead of the default
p TableB.new.to_sql(registry) == %(WITH "table_a" AS (SELECT "audio_events"."id", "audio_events"."is_reference" AS "is_squanchy_2" FROM "audio_events") SELECT COUNT("table_a"."is_squanchy") AS "count_of_squanchies" FROM "table_a" WHERE "table_a"."is_squanchy" = TRUE)

# -- Example: Suffixing

# Now resolve the same Cte graph but with a suffix. Check that all tables and
# references to tables have the suffix applied.
tableB_suffixed = TableB.new(suffix: :rocks)
tableB_suffixed.to_sql

# Try to use the registry from before again, this time with the suffix.
tableB_suffixed_v2 = TableB.new(suffix: :rocks)
tableB_suffixed_v2.to_sql(registry)
# Didn't work - the column reference output in the sql is still 'is_squanchy' and not 'is_squanchy_2' like our injected node has.
# Because the key / name in the registry does not match the name that the node will
# have after the suffix is applied. Change the name in the registry and it will work.

# Note that suffixes are only propagated to un-initialised nodes. Intentionally,
# since we don't want to mutate existing nodes. It's unlikely to be a problem but
# helpful to understand the dependency resolution logic.

# Organize related CTEs into modules, and extend the Cte::Dsl module

# -- Example: Options are propagated
module Beans
  extend Cte::Dsl

  # A base CTE that other CTEs in this module can depend on.
  Base = define_table :bean_base do
    select do
      Project.arel_table.project(Arel.star)
    end
  end

  # A second CTE that depends on the base
  BeanCounter = define_table :beans do
    depends_on base: Beans::Base
    default_options beanstalk: false, bean_type: 'default'

    select do
      base.project(Arel.star.count.as(options[:bean_type]))
    end
  end
end

bean_counter_instance = Beans::BeanCounter.new(options: { bean_type: 'magic' })
puts bean_counter_instance.to_sql == %(WITH "bean_base" AS (SELECT * FROM "projects") SELECT COUNT(*) AS "magic" FROM "bean_base")
bean_counter_instance.execute

# Multiple dependencies
module Beans
  extend Cte::Dsl

  BeanDetails = define_table :bean_details do
    default_options beanstalk: false, bean_type: 'default'

    depends_on base: Beans::Base, counter: Beans::BeanCounter

    select do
      Arel::SelectManager.new.project(
      Arel.json(
        base[:id],
        counter[:default]
      )
    ).from([base, counter])
    end
  end
end
p Beans::BeanDetails.new.execute.to_a
