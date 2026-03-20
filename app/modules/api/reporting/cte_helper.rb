# frozen_string_literal: true

module Api
  module Reporting
    # Mixin providing a helper for building CTE nodes
    module CteHelper
      def cte(table, query) = Arel::Nodes::As.new(table, query)
    end
  end
end
