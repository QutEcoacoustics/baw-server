# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides support for parsing a query from a hash.
  module Projection
    extend ActiveSupport::Concern
    extend Validate

    NEW_KEYS = [:only, :add, :remove].freeze
    OLD_KEYS = [:include, :exclude].freeze

    private

    # Create column projection.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @return [Arel::Nodes::Node,Hash,nil] projection
    def project_column(table, column_name, allowed)
      return project_association(table, column_name) if association_field?(column_name)

      # allow a custom field to be used in a projection,
      return project_custom_field(table, column_name, @custom_fields2) if custom_field_defined?(column_name,
        @custom_fields2)

      validate_table_column(table, column_name, allowed)
      table[column_name]
    end

    # allow a custom field to be used in a projection,
    # Can either:
    # - inject custom arel for a calculated field
    # - or use a hint from the field for what additional columns to select for a virtual field
    # @return [Hash] with two keys: `:projection` and `:joins`
    def project_custom_field(table, column_name, custom_fields2, as: nil)
      arel = nil
      joins = []

      # two scenarios: calculated or virtual
      if custom_field_is_calculated?(column_name, custom_fields2)
        #   1. this is a calculated column that can be calculated in query
        #     - then we supply the arel directly here
        #     - and also any joins needed
        as ||= column_name
        build_custom_calculated_field(column_name, custom_fields2) => { arel:, joins: }
        # `as` is needed to name the column so it can deserialize into active model
        #
        # There is something funny with with the .alias method on arel-extensions's
        # Function class that causes a double alias to be emitted when queries
        # are cloned. I never worked out the exact cause, but creating the node
        # explicitly fixed the issue.
        arel = ::Arel::Nodes::As.new(arel, table[as].unqualified) unless arel.nil?
      elsif custom_field_is_virtual?(column_name, custom_fields2)
        #   2. this is a virtual column who's result will be calculated post-query in rails
        #      and we're just fetching source columns
        #     - then we use query_attributes and apply transform after the fact
        #     - virtual fields don't support additional joins at this time, so `joins`` is just left empty
        arel = build_custom_virtual_field(column_name, custom_fields2, table)
      else
        # if nil, this is not a custom field
        raise "unknown field type #{field_type}" unless field_type.nil?
      end

      { projection: arel, joins: Array(joins) }
    end

    def project_association(base_table, column_name)
      parse_table_field(base_table, column_name) => { table_name:, field_name:, arel_table:, model:, filter_settings: }
      custom_fields2 = filter_settings[:custom_fields2] || {}
      allowed = allowed_fields(filter_settings[:render_fields], custom_fields2)

      joins, match = build_joins(model, @valid_associations)
      raise CustomErrors::FilterArgumentError, "Association is not matched for #{column_name}" unless match

      # allow a custom field to be used in a projection,
      custom_joins = []
      if custom_field_defined?(field_name, custom_fields2)
        # but don't allow virtual fields to be projected for associations. We _could_ allow them but much more work
        # needs to be done in the filter module to support them (also in API response where transforms are applied).
        # We agreed that if a virtual field is needed we just have to load the resource at it's own endpoint.
        # Unlike custom fields, there is limited use for projecting virtual fields in associations because there
        # is also no way to filter by them.
        if custom_field_is_virtual?(field_name, custom_fields2)
          raise CustomErrors::FilterArgumentError,
            "Custom field `#{field_name}` is virtual and not supported for projection through an association"
        end

        project_custom_field(arel_table, field_name, custom_fields2, as: column_name.to_s) => {
          projection:,
          joins: custom_joins
        }
      else
        validate_table_column(arel_table, field_name, allowed)
        projection = arel_table[field_name].as(column_name.to_s)
      end

      joins = joins.flat_map { |j|
        table = j[:join]
        # assume this is an arel_table if it doesn't respond to .arel_table
        arel_table = table.respond_to?(:arel_table) ? table.arel_table : table
        base_table.join(arel_table, Arel::Nodes::OuterJoin).on(j[:on]).join_sources
      }

      { projection:, joins: joins + custom_joins }
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
        joins = projection[:joins] || []
        query = query.joins(*joins) if joins.present?
        query = apply_projection_with_select(query, projection[:projection])

        return query
      end

      apply_projection_with_select(query, projection)
    end

    def apply_projection_with_select(query, projection)
      # We sometimes get an array of columns to include.
      # However because Attribute is a struct, it responds to the spread protocol
      # and then it deconstructs into a table and unqualified column pair.
      # This is really confusing because the results query selects the whole
      # row into one column (select table from table produces the whole row in one column).
      case projection
      in ::Arel::Attributes::Attribute | ::Arel::Nodes::Node | Struct
        query.select(projection)
      in Array
        query.select(*projection)
      else
        raise "unknown projection type `#{projection&.class&.name}`: #{projection&.inspect}"
      end
    end

    def format_new_keys
      NEW_KEYS.format_inline_list(delimiter: ', ', quote: '`')
    end

    def format_old_keys
      OLD_KEYS.format_inline_list(delimiter: ', ', quote: '`')
    end

    # parses the projection from params.
    # Also validates.
    # Also normalizes the projection from the legacy format
    # into the new format.
    # @param [Hash] the effective projection
    def validate_and_normalize_projection(projection, render_fields:)
      bad = -> { raise CustomErrors::FilterArgumentError, "Projection invalid: #{_1}" }

      if projection.nil? || (projection.is_a?(Hash) && projection.empty?)
        return { only: render_fields, add: [], remove: [] }
      end

      bad['must be a Hash'] unless projection.is_a?(Hash)

      keys = projection.keys
      has_new_keys = keys.intersect?(NEW_KEYS)
      has_old_keys = keys.intersect?(OLD_KEYS)

      # if there is a mix of old and new keys, raise an error
      if has_new_keys && has_old_keys
        bad["cannot mix deprecated projection keys (#{format_old_keys}) with new keys (#{format_new_keys})"]
      elsif has_new_keys
        # no other keys allowed
        bad["must only contain [#{format_new_keys}]"] unless (keys - NEW_KEYS).empty?
      elsif has_old_keys
        bad["must have exactly 1 of [#{format_old_keys}] if using legacy projection"] if keys.size != 1
      else
        bad["can only contain [#{format_new_keys}] or [#{format_old_keys}]"]
      end

      projection.each do |key, value|
        bad["field list for `#{key}` must be an Array"] unless value.is_a?(Array)

        bad["field list for `#{key}` must not be empty"] if OLD_KEYS.include?(key) && value.empty?

        # ensure all fields are strings and convert case if needed
        value.map! do |field|
          bad["all fields in `#{key}` must be a String"] unless field.is_a?(String) || field.is_a?(Symbol)
          bad["all fields in `#{key}` must not be empty"] if field.blank?

          CleanParams.clean(field)
        end
      end

      # finally normalize the projection
      if has_new_keys
        {
          only: projection.fetch(:only, render_fields),
          add: projection.fetch(:add, []),
          remove: projection.fetch(:remove, [])
        }
      else
        # we already validated we only have one key
        key = keys.first
        if key == :include
          # old behaviour: include means only return specified fields
          { only: projection[key], add: [], remove: [] }
        elsif key == :exclude
          { only: render_fields, add: [], remove: projection[key] }
        else
          # this should never happen because we validated the keys above
          raise "Unknown projection key: #{key}"
        end
      end
    end

    # Turns a projection hash an array of strings.
    # @param projection [Hash]
    # @return [Set<String>] flattened projection
    def flatten_projection_hash(projection)
      unless projection in { only:, add:, remove: }
        raise 'Unexpected projection hash'
      end

      Set.new(only).merge(add).subtract(remove)
    end
  end
end
