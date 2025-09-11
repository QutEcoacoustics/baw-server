# frozen_string_literal: true

module Report
  module Cte
    class TopologicalSort
      DEPENDENCY_ACCESSOR = ->(x) { x.dependencies.values }

      def traverse(node, registry = {})
        current_node = registry.fetch(node.name, node)
        depth_first_search(current_node, Set.new, [], registry)
      end

      def depth_first_search(node, visited, result, registry)
        registry[node.name] ||= node

        return result if visited.include?(node.name)

        visited.add(node.name)

        DEPENDENCY_ACCESSOR.call(node).each do |dependency|
          current_node = registry.fetch(dependency.name, dependency)
          depth_first_search(current_node, visited, result, registry)
        end

        result << node unless result.include?(node)
        result
      end
    end
  end
end
