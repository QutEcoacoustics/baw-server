# frozen_string_literal: true

module Report
  module Expression
    class Cte
      # @param table [Arel::Table] The table to use for the CTE
      # @param cte [Arel::Nodes::As] The CTE node
      # @param depends_on [Array] The dependencies for the CTE
      def initialize(table, cte, dependencies = [])
        @table = table
        @cte = cte
        @dependencies = dependencies
      end
      attr_reader :table, :cte, :dependencies
    end

    # Collection of report expressions
    class Collection
      attr_accessor :entries

      def initialize
        @entries = {}
      end

      # @param name [Symbol] The name tag to use for the expression
      # @param object [Expression] The expression object to add
      # @return [Symbol] name key to access the expression
      def add(name, object)
        raise ArgumentError unless object.is_a?(Report::Expression::Cte)

        entries[name] = object
        name
      end

      # get or slice the collection from an input array
      def get(*input)
        return unless input.is_a?(Symbol) || input.is_a?(Array)

        self_new = self.class.new
        self_new.entries = entries.slice(*input)
        self_new
      end

      # Return an array of ctes from the collection, ordered 'as-is'. Used to
      # pass as an argument to the Arel `with` method.
      # Note: can prefix with `.get` to limit the CTEs.
      # @return [Array<Arel::Nodes::As>]
      def ctes
        entries.map { |_, query| query.cte }
      end

      # return all tables in the collection
      # chains with .get
      # @return [Array] Array of tables
      def tables
        entries.map { |_, query| query.table }
      end

      def slice_with_dependencies(from_key)
        raise ArgumentError, "key '#{from_key}' not found in collection" unless entries.key?(from_key)

        required_ctes = transitive_dependencies(from_key)
        # filter / get the required expression objects in the required_ctes
        # order and return the new collection
        ordered_collection = entries.slice(*required_ctes)

        self_new = self.class.new
        self_new.entries = ordered_collection
        self_new
      end

      # Select all from the specified table, including only necessary CTEs based
      # on dependencies
      # @param from_key [Symbol] The key of the table to select from
      # @return [Arel::SelectManager] Select manager with required CTEs
      def select(from_key)
        raise ArgumentError, "from_key '#{from_key}' not found in collection" unless entries.key?(from_key)

        required_ctes = transitive_dependencies(from_key)
        ordered_ctes = required_ctes.map { |key| entries[key].cte }
        entries[from_key].table
          .project(Arel.star)
          .with(ordered_ctes)
      end

      def transitive_dependencies(key)
        visited = Set.new
        ordered = []

        dfs = lambda { |current_key|
          raise ArgumentError, "Dependency '#{current_key}' not found" unless entries.key?(current_key)
          return if visited.include?(current_key)

          visited.add(current_key)
          deps = entries[current_key].dependencies || []
          deps.each do |dep|
            if visited.include?(dep) && ordered.exclude?(dep)
              raise ArgumentError,
                "Circular dependency detected at '#{dep}'"
            end

            dfs.call(dep)
          end
          ordered << current_key
        }

        dfs.call(key)
        ordered
      end
    end
  end
end
