# frozen_string_literal: true

module Report
  module Cte
    module Dsl
      # Define a new subclass of Node
      #
      # Note: The definition block follows normal Ruby block scoping rules.
      # It inherits the lexical scope where it is defined, including access
      # to local variables and constants from that outer scope.
      # Importantly, if a local variable from the outer scope is assigned
      # a new value within this block, that change *will* affect the
      # variable in the surrounding (outer) scope. New local variables defined
      # within the block will not be accessible outside the block.
      #
      # @param table_name [Symbol] The default name for the Cte table
      # @param dsl_block [Proc] A block containing DSL method calls to configure the Cte
      # @return [Class] A new subclass of Node
      def define_table(table_name, &dsl_block)
        klass = Class.new(Cte::Node) do
          # store class-level configuration
          @_table_name = table_name
          @_depends_on = {}
          @_default_options = {}
          @_select_block = nil

          # class-level accessors for configuration
          class << self
            attr_accessor :_table_name, :_depends_on, :_default_options, :_select_block
          end

          # DSL method to define named dependencies for the Cte using keyword
          # arguments.
          #
          # Note: Each key becomes an instance method in the select block's evaluation
          # context, that will return the dependency's Arel::Table. The key
          # proovides a consistent interface for accessing a dependency within
          # the context of this specific Cte node's select block, regardless of
          # a dependency's actual state when it is resolved (e.g. table names
          # can change due to suffixes). It does not need to match the name of
          # the dependency node.
          #
          # @param dependencies [Hash{Symbol => Class, Node}]
          def self.depends_on(**dependencies)
            @_depends_on = dependencies
          end

          # DSL method to set default options for the Cte
          # @param opts [Hash] default options
          # @param options_block [Proc] optional block for dsl style options
          def self.default_options(**opts, &options_block)
            @_default_options = options_block ? options_block.call : opts
          end

          # DSL method to define the select logic for the Cte.
          #
          # The block will be evaluated in the context of a `Cte::SelectContext`
          # instance. The context provides accessor methods for the node's
          # options hash (`#options`) and the `Arel::Tables` of any dependencies
          # (`#{dependency_key}`).
          #
          # Note: Because the context of self is changed, methods used within
          # the block should be called with an explicit receiver, like
          # `SomeModule.helper`.
          #
          # @param blk [Proc] Block that returns an Arel::SelectManager or
          # Arel::Nodes::SqlLiteral
          def self.select(&blk)
            @_select_block = blk
          end

          # Instance method to access the class-level default_options. This
          # method is called in the super class to merge default options
          # with initialization options.
          define_method(:default_options) do
            self.class._default_options
          end

          # Initialize instances with class-level defaults. We override
          # initialize to use the stored defaults, so the class acts as a
          # template, while still allowing overrides for name, dependencies,
          # suffix, and the select statement (block).
          define_method(:initialize) do |name = self.class._table_name, dependencies: self.class._depends_on, suffix: nil, options: {}, &block|
            block = self.class._select_block if block.nil?
            super(name, dependencies: dependencies, suffix: suffix, options: options, &block)
          end
        end

        klass.instance_eval(&dsl_block) if dsl_block
        klass
      end

      module_function :define_table
    end
  end
end
