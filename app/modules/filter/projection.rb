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
      return project_custom_field(table, column_name, @custom_fields2) if @custom_fields2.key?(column_name)

      validate_table_column(table, column_name, allowed)
      table[column_name]
    end

    # allow a custom field to be used in a projection,
    # Can either:
    # - inject custom arel for a calculated field
    # - or use a hint from the field for what additional columns to select for a virtual field
    def project_custom_field(_table, column_name, custom_fields2, as: nil)
      # two scenarios:
      field_type = custom_field_type(column_name, custom_fields2)

      #   1. this is a calculated column that can be calculated in query
      #     - then we supply the arel directly here
      if field_type == :calculated
        as ||= column_name
        calculated = build_custom_calculated_field(column_name, custom_fields2)[:arel]
        # `as` is needed to name the column so it can deserialize into active model
        return calculated.as(as.to_s) unless calculated.nil?
      end

      #   2. this is a virtual column who's result will be calculated post-query in rails and we're just fetching source columns
      #     - then we use query_attributes and apply transform after the fact
      return build_custom_virtual_field(column_name, custom_fields2) if field_type == :virtual

      # if nil, this is not a custom field
      raise "unknown field type #{field_type}" unless field_type.nil?

      nil
    end

    def project_association(base_table, column_name)
      parse_table_field(base_table, column_name) => { table_name:, field_name:, arel_table:, model:, filter_settings: }
      custom_fields2 = filter_settings[:custom_fields2] || {}
      allowed = allowed_fields(filter_settings[:render_fields], custom_fields2)

      joins, match = build_joins(model, @valid_associations)
      raise CustomErrors::FilterArgumentError, "Association is not matched for #{column_name}" unless match

      # allow a custom field to be used in a projection,
      if custom_fields2.key?(field_name)
        project_custom_field(arel_table, field_name, custom_fields2, as: column_name.to_s) => projection
      else
        validate_table_column(arel_table, field_name, allowed)
        projection = arel_table[field_name].as(column_name.to_s)
      end

      joins = joins.map { |j|
        table = j[:join]
        # assume this is an arel_table if it doesn't respond to .arel_table
        arel_table = table.respond_to?(:arel_table) ? table.arel_table : table
        { arel_table:, type: Arel::Nodes::OuterJoin, on: j[:on] }
      }

      { projection:, joins:, base_table: }
    end

    # Add projections to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Arel::Nodes::Node>] projections
    # @return [ActiveRecord::Relation] the modified query
    def apply_projections(query, projections)
      new_query = query
      projections.each do |projection|
        new_query = apply_projection(new_query, projection)
      end
      new_query
    end

    # Add projection to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Arel::Nodes::Node] projection
    # @return [ActiveRecord::Relation] the modified query
    def apply_projection(query, projection)
      validate_query(query)
      validate_projection(projection)

      if projection.is_a?(Hash)
        expression = projection[:base_table]
        projection[:joins].each do |join|
          expression = expression.join(join[:arel_table], join[:type]).on(join[:on])
        end
        query = query.joins(expression.join_sources)
        query = query.select(*projection[:projection])

        return query
      end

      query.select(*projection)
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
