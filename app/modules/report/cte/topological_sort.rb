# frozen_string_literal: true

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

module Report
  module Cte
    class DependencyInitialiser
      attr_reader :attributes

      def initialize(cascade_attributes: {})
        @attributes = cascade_attributes
      end

      def call(dependencies)
        dependencies.transform_values { |dep|
          case dep
          in Node
            dep
          in Class => klass if klass <= Node
            klass.new(**attributes)
          else
            unknown_dependency(dep)
          end
        }
      end

      def unknown_dependency(dep)
        raise ArgumentError,
          "Dependency must be a Node or subclass, got: #{dep.class.name} (#{dep.inspect})"
      end
    end
  end
end
