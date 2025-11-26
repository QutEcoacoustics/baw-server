# frozen_string_literal: true

module Api
  # Supports actions that return aggregates of a parent-child relationship
  module GroupBy
    extend ActiveSupport::Concern

    Group = Data.define(:model, :base_query, :projections) {
      def initialize(model:, base_query:, projections:)
        raise 'model must be an ActiveRecord::Base subclass' unless model < ActiveRecord::Base
        raise 'base_query must be an ActiveRecord::Relation' unless base_query.is_a?(ActiveRecord::Relation)
        raise 'projections must be an Hash of aliases to Arel nodes' unless projections.is_a?(Hash)

        super
      end
    }

    included do
    end

    class_methods do
    end

    def do_authorize_group_classes(parent, child)
      raise 'group_parent not set in controller' if parent.nil?
      raise 'group_child not set in controller' if child.nil?

      do_authorize_class(nil, parent)
      do_authorize_class('filter', child)
    end

    private

    def api_filter_params_filter_only!
      if params.key?(:paging) || params.key?(:sort) || params.key?(:projection)
        raise CustomErrors::UnprocessableEntityError,
          'Paging, sorting, and projection parameters are not allowed in group by requests.'
      end

      api_filter_params_filter_only
    end

    def api_filter_params_filter_only
      api_filter_params.to_h.slice(:filter)
    end

    # def api_filter_params_except_filter
    #   api_filter_params.to_h.except(:filter)
    # end

    def group_cte_table
      @group_cte_table ||= Arel::Table.new(:grouped_table)
    end

    def do_group_by_query(
      parent:,
      child:,
      filter_settings:,
      joins: nil
    )
      parent_table = parent.model.arel_table

      child_filter = Filter::Query.new(
        # only allow filtering parameters (no paging, sorting, projection)
        api_filter_params_filter_only!,
        child.base_query,
        child.model,
        filter_settings
      )

      # opts is a strange blend between parent and child opts that would usually
      # come from Settings.api_response.response
      opts = {
        filter: child_filter.filter,
        filter_without_defaults: child_filter.supplied_filter
      }

      grouped_table = group_cte_table
      grouped_query = child_filter
        .query_without_paging_sorting
        .joins(joins)
        .group(parent_table[:id])
        .reselect(
          parent_table[:id].as('parent_id'),
          *child.projections.map { |name, expression| expression.as(name.to_s) }
        )

      grouped_query = parent
        .base_query
        .with(grouped_table.name => grouped_query)
        .joins(
          parent_table
            .join(grouped_table)
            .on(grouped_table[:parent_id].eq(parent_table[:id]))
            .join_sources
        )
        .select(
          *parent.projections.map { |name, expression| expression.as(name.to_s) },
          *child.projections.keys.map { |name| grouped_table[name.to_s] }
        )

      # We're intentionally not doing a filter query or an active record query here.
      # The goal is speed and efficiency
      parent.model.connection_pool.with_connection do |connection|
        connection.exec_query(grouped_query.to_sql) => result
        # This is icky. What happens in real rails code is the ActiveRecord::Result
        # object is consumed by ActiveRecord::Base.instantiate which turns takes
        # in rows of untyped results and column types turns them into model objects.
        columns = result.columns.map(&:to_sym)
        result.cast_values.map do |row|
          columns.zip(row).to_h
        end
      end => results

      [results, opts]
    end

    def respond_group_by(content, opts = {})
      render_format(content, opts)
    end
  end
end
