# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides support for parsing a query from a hash.
  module Projection
    extend ActiveSupport::Concern
    extend Validate

    private

    # Create column projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @return [Arel::Nodes::Node,Hash,nil] projection
    def project_column(table, column_name, allowed)
      return project_association(table, column_name) if association_field?(column_name)

      # allow a custom field to be used in a projection,
      return project_custom_field(table, column_name) if @custom_fields2.key?(column_name)

      # allow field mappings to appear in a projection
      field = build_custom_field(column_name)
      return field unless field.blank?

      validate_table_column(table, column_name, allowed)
      table[column_name]
    end

    # allow a custom field to be used in a projection,
    # use a hint from the field for what additional columns to select
    def project_custom_field(table, column_name)
      @custom_fields2.dig(column_name, :query_attributes).map do |hint|
        # implicitly allow the hint here - the hint is
        # provided by filter settings and not user so
        # we assume it is secure
        validate_table_column(table, hint, [hint])
        table[hint]
      end
    end

    def project_association(base_table, column_name)
      parse_table_field(base_table, column_name) => {table_name:, field_name:, arel_table:, model:, filter_settings:}
      joins, match = build_joins(model, @valid_associations)
      raise CustomErrors::FilterArgumentError, "Association is not matched for #{column_name}" unless match

      projection = arel_table[field_name].as(column_name.to_s)
      joins = joins.map { |j|
        table = j[:join]
        # assume this is an arel_table if it doesn't respond to .arel_table
        arel_table = table.respond_to?(:arel_table) ? table.arel_table : table
        { arel_table: arel_table, type: Arel::Nodes::OuterJoin, on: j[:on] }
      }

      { projection: projection, joins: joins, base_table: base_table }
    end

    #
    #     # this might be used later...
    #
    #     # Create average projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_average(table, column_name, allowed, projection_alias)
    #       validate_table_column(table, column_name, allowed)
    #       agg = table[column_name].average
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create count projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] projection_alias
    #     # @param [Boolean] distinct
    #     # @return [Arel::Nodes::Node] projection
    #     def project_count(table, column_name, allowed, projection_alias, distinct = false)
    #       validate_table_column(table, column_name, allowed)
    #       agg = table[column_name].count(distinct)
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create maximum projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_maximum(table, column_name, allowed, projection_alias)
    #       validate_table_column(table, column_name, allowed)
    #       agg = table[column_name].maximum
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create minimum projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_minimum(table, column_name, allowed, projection_alias)
    #       validate_table_column(table, column_name, allowed)
    #       agg = table[column_name].minimum
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create sum projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_sum(table, column_name, allowed, projection_alias)
    #       validate_table_column(table, column_name, allowed)
    #       agg = table[column_name].sum
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create extract projection.
    #     # @param [Arel::Table] table
    #     # @param [Symbol] column_name
    #     # @param [Array<Symbol>] allowed
    #     # @param [String] extract_field
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_extract(table, column_name, allowed, extract_field, projection_alias)
    #       validate_table_column(table, column_name, allowed)
    #       validate_projection_extract(extract_field)
    #       agg = table[column_name].extract(extract_field)
    #       project_aggregate(agg, projection_alias)
    #     end
    #
    #     # Create aggregate projection.
    #     # @param [Arel::Nodes::Node] projection
    #     # @param [String] projection_alias
    #     # @return [Arel::Nodes::Node] projection
    #     def project_aggregate(projection, projection_alias)
    #       projection_alias_sanitized = sanitize_projection_alias(projection_alias)
    #       if projection_alias_sanitized.blank?
    #         projection
    #       else
    #         projection.as(projection_alias_sanitized)
    #       end
    #     end
  end
end
