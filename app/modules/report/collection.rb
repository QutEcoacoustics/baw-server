# frozen_string_literal: true

module Report
  class Collection
    def initialize(entries = {})
      @entries = validate(entries)

      yield(self) if block_given?
    end

    # @return [Hash{Symbol => Report::CteNode}] The collection of CTEs
    attr_reader :entries

    # Returns the entry associated with the given key, if found
    # @param key [Symbol] identifier for the CteNode
    # @return [Report::CteNode, nil] The CteNode associated with the key, or nil if not found
    def [](key)
      @entries[key.to_sym]
    end

    # Associates the given CteNode with the given key in the collection
    # @param key [Symbol] identifier for the CteNode
    # @param node [Report::CteNode]
    def []=(key, node)
      raise ArgumentError unless node.is_a?(Report::CteNode)

      @entries[key.to_sym] = node
    end

    # Merges another collection into this one, returning a new collection.
    #
    # @param other [Report::Collection] The other collection to merge.
    # @return [Report::Collection] A new collection with merged entries.
    def merge(other)
      raise ArgumentError, 'Can only merge with another Report::Collection' unless other.is_a?(Report::Collection)

      merged_entries = entries.merge(other.entries)
      self.class.new(merged_entries)
    end

    # Returns the CTE nodes for all entries, in insertion order.
    #
    # @return [Array<Arel::Nodes::As>] The CTE nodes.
    def ctes
      entries.values.map(&:cte)
    end

    # Return a select manager for any Report::CteNode in the
    # collection. The select manager will be built using the CteNode's
    # Arel::Table and will include all CTE dependencies in the `with` clause,
    # in topological order.
    #
    # @param key [Symbol] The name of the CteNode to project
    # @return [Arel::SelectManager]
    def select(key)
      raise ArgumentError, "from_key '#{key}' not found in collection" unless entries.key?(key)

      ordered_collection = sort(key)
      ordered_collection[key].table
        .project(Arel.star)
        .with(ordered_collection.ctes)
    end

    # Returns a new collection with the specified CTE and its dependencies,
    # sorted in topological order. Any CTE in the collection can be specified as
    # the root of the dependency graph. CTEs that do not appear in the
    # dependency graph will not be included in the result.
    #
    # Typically the root CTE is the one that will be used to project a result.
    #
    # @param key [Symbol] The key of the root CTE.
    # @return [Report::Collection] a new collection subset of target
    #   CTE and its dependencies.
    def sort(key)
      raise ArgumentError, "CTE '#{key}' not found in collection" unless entries.key?(key)

      required_keys = resolve_dependency_graph(key)
      slice(required_keys)
    end

    # Return a new collection containing only the specified entries.
    #
    # @param keys [Array<Symbol>] The keys to subset the collection with
    # @return [Report::Expression::Collection] New collection subset
    def slice(keys)
      input = Array(keys).map(&:to_sym)

      self.class.new(entries.slice(*input))
    end

    def inspect
      JSON.pretty_generate(entries, allow_nan: true, max_nesting: false)
    end

    def validate(entries)
      raise ArgumentError, 'entries must be a Hash' unless entries.is_a?(Hash)

      unless entries.values.all? { |v| v.is_a?(Report::CteNode) }
        raise ArgumentError, 'entries must be a Hash of Report::CteNode'
      end

      entries
    end

    # Returns a new collection with all CTEs sorted in topological order.
    #
    # @return [Report::Collection] A new collection with all CTEs in topological order.
    def sort_all
      debugger
      ordered_keys = topological_sort
      slice(ordered_keys)
    end

    # Add a CTE node to the collection
    # @param key [Symbol] identifier for the CteNode
    # @param node [Report::CteNode] the CTE node to add
    def add(key, node)
      raise ArgumentError unless node.is_a?(Report::CteNode)

      @entries[key.to_sym] = node
    end

    private

    # Performs a topological sort on all CTE nodes in the collection.
    #
    # @return [Array<Symbol>] Ordered list of keys in topological order.
    def topological_sort
      visited = Set.new
      result = []
      debugger
      entries.keys.each do |key|
        resolve_dependency_graph(key, visited, result) unless visited.include?(key)
      end
      result
    end

    # Resolves the dependency graph for a CteNode in the collection using
    # depth-first search.
    #
    # @param [Symbol] key of the cte CteNode to resolve dependencies for.
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
