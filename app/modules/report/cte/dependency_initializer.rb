# frozen_string_literal: true

module Report
  module Cte
    class DependencyInitializer
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
