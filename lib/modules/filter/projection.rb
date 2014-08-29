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
    # @return [Arel::Nodes::Node] projection
    def project_column(table, column_name, allowed)
      validate_table_column(table, column_name, allowed)
      table[column_name]
    end

=begin

    # this might be used later...

    # Create average projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_average(table, column_name, allowed, projection_alias)
      validate_table_column(table, column_name, allowed)
      agg = table[column_name].average
      project_aggregate(agg, projection_alias)
    end

    # Create count projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] projection_alias
    # @param [Boolean] distinct
    # @return [Arel::Nodes::Node] projection
    def project_count(table, column_name, allowed, projection_alias, distinct = false)
      validate_table_column(table, column_name, allowed)
      agg = table[column_name].count(distinct)
      project_aggregate(agg, projection_alias)
    end

    # Create maximum projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_maximum(table, column_name, allowed, projection_alias)
      validate_table_column(table, column_name, allowed)
      agg = table[column_name].maximum
      project_aggregate(agg, projection_alias)
    end

    # Create minimum projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_minimum(table, column_name, allowed, projection_alias)
      validate_table_column(table, column_name, allowed)
      agg = table[column_name].minimum
      project_aggregate(agg, projection_alias)
    end

    # Create sum projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_sum(table, column_name, allowed, projection_alias)
      validate_table_column(table, column_name, allowed)
      agg = table[column_name].sum
      project_aggregate(agg, projection_alias)
    end

    # Create extract projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [String] extract_field
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_extract(table, column_name, allowed, extract_field, projection_alias)
      validate_table_column(table, column_name, allowed)
      validate_projection_extract(extract_field)
      agg = table[column_name].extract(extract_field)
      project_aggregate(agg, projection_alias)
    end

    # Create aggregate projection.
    # @param [Arel::Nodes::Node] projection
    # @param [String] projection_alias
    # @return [Arel::Nodes::Node] projection
    def project_aggregate(projection, projection_alias)
      projection_alias_sanitized = sanitize_projection_alias(projection_alias)
      if projection_alias_sanitized.blank?
        projection
      else
        projection.as(projection_alias_sanitized)
      end
    end
=end

  end
end