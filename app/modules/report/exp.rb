# frozen_string_literal: true

module Report
  module Expression
    # A CTE (Common Table Expression) class that wraps an Arel::Table and
    # Arel::Nodes::As object. The id acts as an identifier. Dependencies
    # are ids of any direct dependencies for this Cte.
    class Cte
      # @param id [Symbol] The identifier for the CTE
      # @param table [Arel::Table] The table to use for the CTE
      # @param cte [Arel::Nodes::As] The CTE node
      # @param dependencies [Array<Symbol>] The identifiers of CTEs this one depends on
      def initialize(id, table, cte, dependencies = [])
        @id = id
        @table = table
        @cte = cte
        @dependencies = dependencies
      end
      attr_reader :id, :table, :cte, :dependencies
    end

    # Parses an array of CTE definitions and builds a collection of CTEs.
    # This class processes CTE definitions one by one, resolving dependencies
    # from already processed CTEs in the collection.
    class ParseCollectionDefinition
      # @param cte_definitions_array [Array<Hash>] An array of hashes, each defining a CTE.
      #   Each hash must contain:
      #   - :id [Symbol] The identifier for the CTE.
      #   And either:
      #   - :method [Symbol] The name of the method to call for generating the CTE.
      #   - :dependencies [Array<Symbol>] (optional) IDs of CTEs this one depends on.
      #   - :args [Array] (optional) Explicit arguments to pass to the method after dependency tables.
      #   - :options [Hash] (optional) An options hash to pass as the last argument to the method.
      #   Or (for pre-defined CTEs):
      #   - :table [Arel::Table] The Arel table.
      #   - :cte_node [Arel::Nodes::As] The Arel CTE node.
      #   - :dependencies [Array<Symbol>] (optional) IDs of CTEs this one depends on.
      # @param context_module [Module] The module or class where the CTE-generating methods are defined.
      # @param initial_collection [Report::Expression::Collection] (optional) An existing collection to add to.
      # @return [Report::Expression::Collection] The collection of generated CTEs.
      def self.call(cte_definitions_array, context_module, initial_collection = nil)
        collection = initial_collection || Report::Expression::Collection.new

        cte_definitions_array.each do |definition|
          new_cte = _process_one_definition(definition, collection, context_module)
          collection.add(new_cte)
        end

        collection
      end

      # Private class methods for internal processing
      class << self
        private

        def _process_one_definition(definition, collection, context_module)
          id = definition.fetch(:id)
          dependencies = definition.fetch(:dependencies, [])

          if definition.key?(:method)
            _build_from_method(id, dependencies, definition, collection, context_module)
          elsif definition.key?(:table) && definition.key?(:cte_node)
            _build_from_predefined(id, dependencies, definition)
          else
            raise ArgumentError,
              "Invalid CTE definition for '#{id}'. Must provide :method or both :table and :cte_node."
          end
        end

        def _build_from_method(id, dependencies, definition, collection, context_module)
          method_name = definition.fetch(:method)
          explicit_args = definition.fetch(:args, [])
          # fetch :options, allow it to be nil if key exists but value is nil, or if key doesn't exist.
          options = definition.key?(:options) ? definition[:options] : nil

          resolved_dependency_tables = _resolve_dependency_tables(dependencies, collection, id,
            "method '#{method_name}'")
          args_for_send = _prepare_method_arguments(resolved_dependency_tables, explicit_args, options)
          table, cte_node = _invoke_cte_method(context_module, method_name, args_for_send, id)

          Report::Expression::Cte.new(id, table, cte_node, dependencies)
        end

        def _build_from_predefined(id, dependencies, definition)
          table = definition.fetch(:table)
          cte_node = definition.fetch(:cte_node)
          Report::Expression::Cte.new(id, table, cte_node, dependencies)
        end

        def _resolve_dependency_tables(dependency_ids, collection, current_cte_id, context_description)
          dependency_ids.map do |dep_id|
            dependency_cte = collection.entries[dep_id]
            unless dependency_cte
              raise ArgumentError,
                "Dependency CTE '#{dep_id}' not found for CTE '#{current_cte_id}' when processing #{context_description}."
            end
            dependency_cte.table
          end
        end

        def _prepare_method_arguments(resolved_tables, explicit_args, options)
          args = resolved_tables + explicit_args
          # Add options to the argument list only if options is not nil.
          # This allows methods to differentiate between no options passed and options: nil passed.
          args << options if !options.nil? || explicit_args.any? { |arg|
            arg.is_a?(Hash) && arg.equal?(options)
          } || resolved_tables.any? { |arg|
                 arg.is_a?(Hash) && arg.equal?(options)
               }
          # A more robust way to handle optional trailing hash arguments if methods rely on Ruby's keyword arg behavior
          # or specific parsing of the last argument if it's a hash:
          # if options.is_a?(Hash) && !options.empty?
          #   args << options
          # elsif !options.nil? # if options is something else (not a hash or nil), or an empty hash you want to pass
          #   args << options
          # end
          # For simplicity, the original logic: args << options if options was fine if options is only ever a hash or nil.
          # The refined logic above is more explicit if options could be, say, false.
          # Given the YARD doc `options [Hash] (optional)`, `args << options if options` (meaning if options is truthy) is usually fine.
          # Let's stick to a simple and common pattern: add if it exists (is not nil).
          args << options unless options.nil?
          # Correction: The previous line `args << options unless options.nil?` might add options twice if it was already part of explicit_args.
          # The original `args << definition[:options] if definition.key?(:options)` in the non-refactored version was safer.
          # Let's refine:
          # The `args = resolved_tables + explicit_args` already includes explicit_args.
          # We only need to add `options` if it's distinct and provided.
          # However, Ruby's `*args` and `send` handles a trailing hash as options automatically if the method expects it.
          # The most straightforward is:
          final_args = resolved_tables + explicit_args
          # Add if key exists, even if value is nil, to match original structure more closely.
          final_args << options if definition.key?(:options)
          # This allows methods to distinguish "options not provided" from "options: nil".
          # If options should only be added if it's a non-nil hash:
          # final_args << options if options.is_a?(Hash)
          final_args # Return the constructed arguments
        end

        def _invoke_cte_method(context_module, method_name, args, current_cte_id)
          unless context_module.respond_to?(method_name)
            raise NoMethodError,
              "Method '#{method_name}' not found in context module '#{context_module}' for CTE '#{current_cte_id}'."
          end
          context_module.send(method_name, *args)
        end
      end
    end

    # Collection of Ctes
    class Collection
      attr_accessor :entries

      def initialize
        @entries = {}
      end

      # Add a CTE to the collection
      # @param object [Report::Expression::Cte] The CTE object to add
      # @return [Symbol] id of the added CTE
      def add(object)
        raise ArgumentError, 'object must be a Report::Expression::Cte' unless object.is_a?(Report::Expression::Cte)
        raise ArgumentError, 'CTE object must have an id' if object.id.nil?
        raise ArgumentError, "Duplicate CTE id: #{object.id}" if entries.key?(object.id)

        entries[object.id] = object
        object.id
      end

      # Get a new collection containing only the specified entries.
      # @param input [Array<Symbol>] The keys to get from the collection
      # @return [Collection] A new collection with the specified entries
      def get(input)
        unless input.is_a?(Array) || input.is_a?(Symbol)
          raise ArgumentError, 'input must be an array or symbol'
          return
        end

        self_new = self.class.new
        self_new.entries = entries.slice(*input)
        self_new
      end

      # Return an array of the @cte fields for each item in the collection,
      # ordered 'as-is', or chain following get_with_dependencies for an
      # ordered collection.
      # @return [Array<Arel::Nodes::As>]
      def ctes
        entries.map { |_, query| query.cte }
      end

      # Return all of the @table fields in the collection. Chain with .get.
      # @return [Array] Array of tables
      def tables
        entries.map { |_, query| query.table }
      end

      # Like get, but includes all ancestors in the graph for the given key.
      def get_with_dependencies(item_name)
        raise ArgumentError, "key '#{item_name}' not found in collection" unless entries.key?(item_name)

        required_ctes = resolve_dependency_graph(item_name)
        ordered_collection = entries.slice(*required_ctes)
        get(ordered_collection.keys)
      end

      # Return a select manager that selects * from the specified table.
      # Recursively finds dependencies for that table to populate the `with`
      # clause. Allows any Cte within a hierarchy to be executed by name
      # regardless of the order in which they are added to the collection.
      # @param from_key [Symbol] The name of the table to select from
      # @return [Arel::SelectManager]
      def select(item_name)
        raise ArgumentError, "from_key '#{item_name}' not found in collection" unless entries.key?(item_name)

        required_ctes = resolve_dependency_graph item_name
        ordered_ctes = required_ctes.map { |item_name| entries[item_name].cte }

        entries[item_name].table
          .project(Arel.star)
          .with(ordered_ctes)
      end

      # Depth-first search to find all dependencies for a given key.
      # @param key [Symbol] The key to find dependencies for
      # @return [Array<Symbol>] An array of keys in topological order
      def resolve_dependency_graph(item_name)
        visited = Set.new
        ordered = []

        depth_first = lambda { |current_key|
          raise ArgumentError, "Dependency '#{current_key}' not found" unless entries.key?(current_key)
          return if visited.include?(current_key)

          visited.add(current_key)
          current_dependencies = entries[current_key].dependencies || []
          current_dependencies.each do |dependency|
            if visited.include?(dependency) && ordered.exclude?(dependency)
              raise ArgumentError,
                "Circular dependency detected at '#{dependency}'"
            end

            depth_first.call(dependency)
          end
          ordered << current_key
        }

        depth_first.call(item_name)
        ordered
      end
    end
  end
end
