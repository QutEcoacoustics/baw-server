# frozen_string_literal: true

# add error handling
module Report
  module Cte
    class NodeEvaluator
      def initialize
        @pipeline = Pipeline.new
          .add_step(add_methods_to_proc)
          .add_step(add_formatter_to_proc)
      end

      def using(method_definitions)
        @method_definitions = method_definitions || {}
        self
      end

      def evaluate(proc)
        @pipeline.execute(proc.dup).call
      end

      private

      def add_methods_to_proc
        lambda { |passed_proc|
          environment = passed_proc.binding.eval('self')
          @method_definitions&.each do |method_name, value|
            environment.define_singleton_method(method_name) { value }
          end
          passed_proc
        }
      end

      def add_formatter_to_proc
        lambda { |proc_to_wrap|
          lambda {
            format_result_as_select_manager(proc_to_wrap.call)
          }
        }
      end

      def format_result_as_select_manager(result)
        case result
        when supported_arel_node? then result
        when coercible_arel_node? then arel_project result
        else
          unsupported_result_type result
        end
      end

      def unsupported_result_type(result)
        raise ArgumentError, "I don't know how to format #{result}"
      end

      def supported_arel_node?
        ->(result) { result.class.in?([Arel::SelectManager, Arel::Nodes::UnionAll, ArelExtensions::Nodes::UnionAll]) }
      end

      def coercible_arel_node?
        ->(result) { result.is_a?(Arel::Nodes::SqlLiteral) }
      end

      def arel_project(result)
        Arel::SelectManager.new.project(result)
      end
    end
  end
end
