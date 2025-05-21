# frozen_string_literal: true

module Report
  module Expression
    # A CTE (Common Table Expression) class that wraps an Arel::Table and
    # Arel::Nodes::As object. The name acts as an identifier. Dependencies
    # are names of any direct dependencies for this Cte. These can be used to
    # compose a chain of Ctes that are resolved in the correct order.
    # NOTE: This class should have a name: field, instead of having it named
    # when adding to a collection. A collection should just be a container for
    # CTEs. Then it makes more sense having dependencies here too.
    class Cte
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

    # Collection of Ctes
    class Collection
      attr_accessor :entries

      def initialize
        @entries = {}
      end

      # Add a CTE to the collection
      # TODO remove name as a parameter and use the name from the CTE object.
      # @param name [Symbol] The name tag to use for the expression
      # @param object [Expression] The expression object to add
      # @return [Symbol] name key to access the expression
      def add(name, object)
        raise ArgumentError unless object.is_a?(Report::Expression::Cte)

        entries[name] = object
        name
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
