# frozen_string_literal: true

module Report
  # I don't really like having this namespace maybe the classes can be moved
  module TableExpression
    # Facilitates the management of CTEs (Report::TableExpression::Datum)
    # Provides methods to retrieve CTEs in topological order, based on their
    # dependencies.
    class Collection
      def initialize(collection = {})
        validate collection
        @entries = collection.is_a?(Hash) ? collection.dup : collection.entries.dup
      end

      # @return [Hash{Symbol => Report::TableExpression::Datum}] The collection of CTEs
      attr_reader :entries

      # Return a select manager for any Report::TableExpression::Datum in the
      # collection. The select manager will be built using the Datum's
      # Arel::Table and will include all CTE dependencies in the `with` clause,
      # in topological order.
      #
      # @param key [Symbol] The name of the Datum to project
      # @return [Arel::SelectManager]
      def select(key)
        raise ArgumentError, "from_key '#{key}' not found in collection" unless entries.key?(key)

        ordered_collection = get_with_dependencies(key)
        ordered_collection.entries[key].table
          .project(Arel.star)
          .with(ordered_collection.ctes)
      end

      # Retrieves a new collection with the specified CTE and its dependencies.
      #
      # @param key [Symbol] The key of the target CTE.
      # @return [TableExpression::Collection] a new collection subset of target
      #   CTE and its dependencies.
      def get_with_dependencies(key)
        raise ArgumentError, "CTE '#{key}' not found in collection" unless entries.key?(key)

        required_keys = resolve_dependency_graph(key)
        get(required_keys)
      end

      # Return a new collection containing only the specified entries.
      #
      # @param keys [Array<Symbol>] The keys to subset the collection with
      # @return [Report::Expression::Collection] New collection subset
      def get(keys)
        input = keys.is_a?(Array) ? keys.map(&:to_sym) : [keys.to_sym]

        # self_new = self.class.new
        # self_new.entries = entries.slice(*input)
        self.class.new(entries.slice(*input))
      end

      # Returns the CTE nodes for all entries, in insertion order.
      #
      # @return [Array<Arel::Nodes::As>] The CTE nodes.
      def ctes
        entries.values.map(&:cte)
      end

      # Returns the Arel tables for all entries in the collection.
      #
      # @return [Array<Arel::Table>] The Arel tables.
      def tables
        tables = entries.values.map(&:table)
        return tables.first if tables.size == 1

        tables
      end

      # @param key [Symbol] identifier for the Datum
      # @param datum [TableExpression::Datum]
      # @return [Symbol] identifier
      def add(key, datum)
        raise ArgumentError unless datum.is_a?(Report::TableExpression::Datum)

        entries[key.to_sym] = datum
        key
      end

      def inspect
        JSON.pretty_generate(entries, allow_nan: true, max_nesting: false)
      end

      def validate(collection)
        return if collection.is_a?(Report::TableExpression::Collection) || collection.is_a?(Hash)

        raise ArgumentError,
          'entries must be a Report::TableExpression::Collection or a Hash of Report::TableExpression::Datum'
      end

      private

      # Resolves the dependency graph for a Datum in the collection using
      # depth-first search.
      #
      # @param [Symbol] key of the cte Datum to resolve dependencies for.
      # @return [Array<Symbol>] Ordered list of keys
      def resolve_dependency_graph(key, visited = Set.new, result = [])
        return result if visited.include?(key)

        visited.add(key)

        dependencies = entries[key]&.depends_on || []
        dependencies.each { |dep| resolve_dependency_graph(dep, visited, result) }

        result << key unless result.include?(key)
        result
      end
    end
  end
end
