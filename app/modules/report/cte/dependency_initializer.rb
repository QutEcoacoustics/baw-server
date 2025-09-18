# frozen_string_literal: true

module Report
  module Cte
    class DependencyInitializer
      attr_reader :attributes

      # @param cascade_attributes [Hash] Attributes to pass to dependency classes when initializing
      def initialize(cascade_attributes: {})
        @attributes = cascade_attributes
      end

      # @param dependencies [Hash{Symbol => Report::Cte::Node, Class}]
      # @return [Hash{Symbol => Report::Cte::Node}]
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
        raise DependencyError,
          "Dependency must be a Node instance or subclass, got: #{dep.class.name} (#{dep.inspect})"
      end

      class DependencyError < StandardError; end
    end
  end
end
