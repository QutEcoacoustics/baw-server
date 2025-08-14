# frozen_string_literal: true

module Filter
  # Provides support for parsing a filter from a hash to build a query.
  class Build
    include Comparison
    include Core
    include Custom
    include CustomField
    include Projection
    include Subset
    include Validate
    include Expressions

    # When parsing truncated dates, we use this base date as the default values
    # to pick any missing components from. 0000-01-01 00:00:00 UTC
    DEFAULT_DATE = Time.utc(0)

    # Create an instance of Build.
    # @param [Arel::Table] table
    # @param [Hash] filter_settings
    # @return [void]
    def initialize(table, filter_settings)
      @table = table

      validate_filter_settings(filter_settings)
      @filter_settings = filter_settings

      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      @text_fields = filter_settings.include?(:text_fields) ? filter_settings[:text_fields].map(&:to_sym) : []
      @valid_associations = filter_settings[:valid_associations]
      @custom_fields2 = filter_settings[:custom_fields2] || {}

      @valid_conditions = [
        # comparison
        :eq, :equal,
        :not_eq, :not_equal,
        :lt, :less_than,
        :not_lt, :not_less_than,
        :gt, :greater_than,
        :not_gt, :not_greater_than,
        :lteq, :less_than_or_equal,
        :not_lteq, :not_less_than_or_equal,
        :gteq, :greater_than_or_equal,
        :not_gteq, :not_greater_than_or_equal,

        # subset
        :range, :in_range,
        :not_range, :not_in_range,
        :in,
        :not_in,
        :contains, :contain,
        :not_contains, :not_contain, :does_not_contain,
        :starts_with, :start_with,
        :not_starts_with, :not_start_with, :does_not_start_with,
        :ends_with, :end_with,
        :not_ends_with, :not_end_with, :does_not_end_with,
        :regex, :regex_match, :matches,
        :not_regex, :not_regex_match, :does_not_match, :not_match
      ]
    end

    # Build projections from a hash.
    # @param fields [Array<Symbol>] fields to project
    # @return [Array<Arel::Attributes::Attribute, Hash>] projections
    def projections(fields)
      allowed = allowed_fields
      projection_expressions = fields.map { |projection_name| project_column(@table, projection_name, allowed) }

      raise 'projection list should not have nils' if projection_expressions.any?(&:nil?)
      raise 'projection list should not have arrays' if projection_expressions.any? { |item| item.is_a?(Array) }

      projection_expressions
    end

    def allowed_fields(render_fields = @render_fields, custom_fields2 = @custom_fields2)
      (render_fields + custom_fields2.keys).uniq
    end

    # Parse a filter.
    # @param [Hash] filter_hash
    # @return [Array]
    def parse(filter_hash)
      parse_filter(filter_hash)
    end

    # Build an exists query for a many to many join.
    # This eliminates the potential for duplicate results due to many to many relation.
    # @param [Arel::Table] result_table Arel table for outer select
    # @param [Arel::Table] filter_table Arel table for inner select
    # @param [Arel::Nodes::Node] filter
    # @param [Hash] opts the options for additional information.
    # @option opts [Symbol] :result_table_id (result_table.name) id field for result table
    # @option opts [Symbol] :filter_table_id (filter_table.name) id field for filter table
    # @option opts [Arel::Table] :many_table (result_table + filter_table) Arel table for many to many
    # @option opts [Symbol] :many_table_result_id (result_table.name.singular id) many to many id field for result table
    # @option opts [Symbol] :many_table_filter_id (filter_table.name.singular id) many to many id field for filter table
    # @param [Boolean] is_negated true for 'NOT EXISTS'
    # @return [Arel::Nodes::Node] Arel query
    def build_exists(result_table, filter_table, filter = nil, opts = {}, is_negated = false)
      validate_table(result_table)
      validate_table(filter_table)

      validate_node_or_attribute(filter) if filter.present?
      validate_hash(opts) if opts.present?

      result_table_name = result_table.name.to_s
      result_table_id = opts[:result_table_id] || :id

      filter_table_name = filter_table.name.to_s
      filter_table_id = opts[:filter_table_id] || :id

      many_table = opts[:many_table] || Arel::Table.new([result_table_name, filter_table_name].sort.join('_').to_sym)
      many_table_result_id = opts[:many_table_result_id] || :"#{result_table_name.singularize}_id"
      many_table_filter_id = opts[:many_table_filter_id] || :"#{filter_table_name.singularize}_id"

      # e.g. - build_exists(Site.arel_table, Project.arel_table)

      # SELECT s.*
      # FROM sites s
      # WHERE [NOT] EXISTS (
      #   SELECT p.*
      #   FROM projects p
      #   INNER JOIN projects_sites ps ON p.id = ps.project_id
      #   WHERE ps.site_id = s.id
      #   AND (*filter*)
      # )

      # SELECT
      # FROM "sites"
      # WHERE EXISTS (
      # SELECT 1
      # FROM "projects"
      # INNER JOIN "projects_sites" ON "projects"."id" = "projects_sites"."project_id"
      # WHERE "projects_sites"."site_id" = "sites"."id"
      # )

      # SELECT
      # FROM "sites"
      # WHERE NOT (
      # EXISTS (
      # SELECT 1
      # FROM "projects"
      # INNER JOIN "projects_sites" ON "projects"."id" = "projects_sites"."project_id"
      # WHERE "projects_sites"."site_id" = "sites"."id"
      # )
      # )

      query = filter_table
        .join(many_table).on(filter_table[filter_table_id].eq(many_table[many_table_filter_id]))
        .where(many_table[many_table_result_id].eq(result_table[result_table_id]))

      query = query.where(filter) if filter

      query = query.project(1).exists

      query = query.not if is_negated

      result_table.where(query)
    end

    # Build table field from field symbol.
    # @param [Arel::Table] table
    # @param [Symbol] field
    # @return [Arel::Table, Symbol, Hash] table, field, filter_settings
    def parse_table_field(table, field)
      validate_table(table)
      raise CustomErrors::FilterArgumentError, 'Field name must be a symbol.' unless field.is_a?(Symbol)

      if association_field?(field)
        parse_other_table_field(table, field)
      else

        # table name may not be the same as model / controller name :(
        model = to_model(table)
        #controller = (filter_settings[:controller].to_s + '_controller').classify.constantize

        {
          table_name: table.name,
          field_name: field,
          arel_table: table,
          model:,
          filter_settings: @filter_settings
        }
      end
    end

    # Runs build_associations on the valid associations and caches the result.
    def composed_associations(table)
      @composed_associations ||= {}

      unless @composed_associations.key?(table)
        @composed_associations[table] ||= build_associations(@valid_associations, table)
      end

      @composed_associations[table]
    end

    private

    # Recursively parse a filter hash.
    # @param [Hash, Symbol] primary
    # @param [Hash, Object] secondary
    # @param [nil, Hash] extra
    # @return [Condition, Array<Condition>]
    def parse_filter(primary, secondary = nil, extra = nil)
      case primary
      when Hash
        if primary.blank? || primary.empty?
          raise CustomErrors::FilterArgumentError.new("Filter hash must have at least 1 entry, got #{primary.size}.",
            { hash: primary })
        end
        if extra.present?
          raise CustomErrors::FilterArgumentError.new("Extra must be null when processing a hash, got #{extra}.",
            { hash: primary })
        end

        primary.flat_map do |key, value|
          #! recursive
          parse_filter(key, value, secondary)
        end
      when Array
        raise CustomErrors::FilterArgumentError, 'Filter arrays must not be empty' if primary.empty?

        primary.flat_map do |value|
          unless value.is_a?(Hash)
            raise CustomErrors::FilterArgumentError,
              "Filter arrays can only contain other hashes; `#{value}` is not valid"
          end

          #! recursive
          parse_filter(value)
        end
      when Symbol

        case primary
        when :and, :or
          combiner = primary
          filter_hash = secondary
          #! recursive
          result = parse_filter(filter_hash)
          combiner_one(combiner, result)
        when :not
          #combiner = primary
          filter_hash = secondary

          #! recursive
          result = parse_filter(filter_hash)

          combiner_not(result)
        when *@valid_fields, /\./
          field = primary
          field_conditions = secondary
          info = parse_table_field(@table, field)
          #! recursive
          result = parse_filter(field_conditions, info)

          build_subquery(info, result)

        when *@valid_conditions
          filter_name = primary
          filter_value = secondary
          info = extra

          if info.blank?
            raise CustomErrors::FilterArgumentError,
              "Attribute is a child of the operator. The attribute should be the parent of `#{primary}`."
          end

          table = info[:arel_table]
          column_name = info[:field_name]
          valid_fields = info[:filter_settings][:valid_fields]
          custom_fields2 = info[:filter_settings][:custom_fields2] || {}
          model = info[:model]
          joins = []

          # check if this is a custom field
          if custom_field_defined?(column_name, custom_fields2)
            if custom_field_is_calculated?(column_name, custom_fields2)
              custom_field = build_custom_calculated_field(column_name, custom_fields2)

              # if a custom field use information supplied
              custom_field => { type: node_type, arel: field_node, joins: }
            else
              raise CustomErrors::FilterArgumentError,
                "Custom field `#{column_name}` is virtual and not supported for filtering"
            end
          else
            # if not, pull column out of active record information
            validate_table_column(table, column_name, valid_fields)

            field_node = table[column_name]
            node_type = model.columns_hash[column_name.to_s].type
          end

          if expression?(filter_value)
            transforms, field_node, filter_value, last_type = compose_expression(
              filter_value,
              model:,
              column_name:,
              column_node: field_node,
              column_type: node_type
            )

            # we normalize the value here because the expression may have changed the type
            filter_value = normalize_value(last_type, filter_value)

            return Models::Condition.new(
              predicate: condition_node(filter_name, field_node, filter_value),
              transforms:
            )
          end

          filter_value = normalize_value(node_type, filter_value)

          Models::Condition.new(
            predicate: condition_node(filter_name, field_node, filter_value),
            joins: joins
          )
        else
          raise CustomErrors::FilterArgumentError, "Unrecognized combiner or field name `#{primary}`."
        end
      else
        raise CustomErrors::FilterArgumentError, "Unrecognized filter component `#{primary}`."
      end
    end

    # ensure values that come from params are normalized to the correct type if they need to be
    def normalize_value(type, value)
      # parsing these string value into actual Time instances results in better comparisons
      # in postgresql. When postgres parses a string it ignore the offset unless it is
      # explicitly cast as a timestamp with time zone.
      return Time.parse(value, DEFAULT_DATE).utc if type == :datetime && value.is_a?(String)

      value
    end

    # Combine an array conditions either with `and` or `or` operators.
    # @param [Symbol] combiner
    # @param [Array<Condition>] conditions
    # @return [Condition] condition
    def combiner_one(combiner, conditions)
      if conditions.blank?
        raise CustomErrors::FilterArgumentError,
          "Combiner '#{combiner}' must have at least 1 entry, got #{conditions.size}."
      end

      Models::Condition.reduce(conditions) do |previous, predicate|
        case combiner
        when :and
          compose_and(previous, predicate)
        when :or
          compose_or(previous, predicate)
        else
          raise CustomErrors::FilterArgumentError, "Unrecognized filter combiner #{combiner}."
        end
      end => combined_conditions

      # wrap this set of expressions in brackets so we don't leak conditions
      # e.g chaining `x AND y OR z` can be very different from `x AND (y OR z)`
      # this produces a lot of brackets...
      combined_conditions.map_predicate do |predicate|
        if predicate.is_a?(::Arel::Nodes::Grouping)
          predicate
        else
          Arel::Nodes::Grouping.new(predicate)
        end
      end
    end

    # @return [Array<Models::Condition>]
    def combiner_not(conditions)
      conditions = Array(conditions)

      conditions.map do |condition|
        raise 'condition must be a Condition' unless condition.is_a?(Models::Condition)

        condition.map_predicate do |predicate|
          raise 'must be a node' unless predicate.is_a?(Arel::Nodes::Node)

          compose_not(predicate)
          # TODO: remove - not sure on correct impl, wait for tests to pass
          # if predicate.respond_to?(:map)
          #   predicate.map { |c| compose_not(c) }
          # else
          #   [compose_not(predicate)]
          # end
        end
      end
    end

    # Build a condition.
    # @param [Symbol] filter_name
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute, String] node
    # @param [Object] filter_value
    # @return [Arel::Nodes::Node] condition
    def condition_node(filter_name, node, filter_value)
      case filter_name

        # comparisons
      when :eq, :equal
        compose_eq_node(node, filter_value)
      when :not_eq, :not_equal
        compose_not_eq_node(node, filter_value)
      when :lt, :less_than
        compose_lt_node(node, filter_value)
      when :not_lt, :not_less_than
        compose_not_lt_node(node, filter_value)
      when :gt, :greater_than
        compose_gt_node(node, filter_value)
      when :not_gt, :not_greater_than
        compose_not_gt_node(node, filter_value)
      when :lteq, :less_than_or_equal
        compose_lteq_node(node, filter_value)
      when :not_lteq, :not_less_than_or_equal
        compose_not_lteq_node(node, filter_value)
      when :gteq, :greater_than_or_equal
        compose_gteq_node(node, filter_value)
      when :not_gteq, :not_greater_than_or_equal
        compose_not_gteq_node(node, filter_value)

        # subsets
      when :range, :in_range
        compose_range_options_node(node, filter_value)
      when :not_range, :not_in_range
        compose_not_range_options_node(node, filter_value)
      when :in
        compose_in_node(node, filter_value)
      when :not_in
        compose_not_in_node(node, filter_value)
      when :contains, :contain
        compose_contains_node(node, filter_value)
      when :not_contains, :not_contain, :does_not_contain
        compose_not_contains_node(node, filter_value)
      when :starts_with, :start_with
        compose_starts_with_node(node, filter_value)
      when :not_starts_with, :not_start_with, :does_not_start_with
        compose_not_starts_with_node(node, filter_value)
      when :ends_with, :end_with
        compose_ends_with_node(node, filter_value)
      when :not_ends_with, :not_end_with, :does_not_end_with
        compose_not_ends_with_node(node, filter_value)
      when :regex, :regex_match, :matches
        compose_regex_node(node, filter_value)
      when :not_regex, :not_regex_match, :does_not_match, :not_match
        compose_not_regex_node(node, filter_value)

        # unknown
      else
        raise CustomErrors::FilterArgumentError, "Unrecognized filter #{filter_name}."
      end
    end

    def build_subquery(info, conditions)
      current_table = info[:arel_table]
      model = info[:model]

      if current_table == @table
        conditions
      else
        base_query = @table
        column_to_match_on = :id
        subquery = base_query.project(@table[column_to_match_on])

        # add relevant joins
        joins, = build_joins(model, @valid_associations)

        joins.each do |j|
          table = j[:join]
          # assume this is an arel_table if it doesn't respond to .arel_table
          arel_table = table.respond_to?(:arel_table) ? table.arel_table : table
          subquery = subquery.join(arel_table, Arel::Nodes::OuterJoin).on(j[:on])
        end

        # add conditions to subquery
        # essentially we're resetting the condition build-up here
        subquery = Models::Condition.apply_to_select_manager(subquery, conditions)

        Models::Condition.new(
          predicate: compose_in(@table, column_to_match_on, [column_to_match_on], subquery)
        )
      end
    end

    def association_field?(name)
      name.to_s.include?('.')
    end

    # Build other table field from field symbol.
    # @param [Arel::Table] table
    # @param [Symbol] field
    # @return [Arel::Table, Symbol, Hash] table, field, filter_settings
    def parse_other_table_field(table, field)
      field_s = field.to_s
      dot_index = field_s.index('.')

      parsed_table = field[0, dot_index].to_sym
      parsed_field = field[(dot_index + 1)..field.length].to_sym

      associations = composed_associations(table)
      models = associations.pluck(:join)
      table_names = associations.map { |association| association[:join].table_name.to_sym }

      validate_name(parsed_table, table_names)

      model = to_model(parsed_table)

      validate_association(model, models)

      model_filter_settings = model.filter_settings
      model_valid_fields = model_filter_settings[:valid_fields].map(&:to_sym)
      arel_table = relation_table(model)

      validate_table_column(arel_table, parsed_field, model_valid_fields)

      {
        table_name: parsed_table,
        field_name: parsed_field,
        arel_table:,
        model:,
        filter_settings: model_filter_settings
      }
    end

    def to_table(model)
      model.table_name
    end

    # @param [Symbol,::Arel::Table]
    def to_model(table_name)
      table_name = table_name.name.to_sym if table_name.is_a?(::Arel::Table)

      raise "A symbol was required, got a #{table_name.class}" unless table_name.is_a?(Symbol)

      # first try to just find the model from the table
      matching_model = table_name.to_s.classify.safe_constantize

      if matching_model.nil?
        # need to ensure all models are actually loaded
        Rails.application.eager_load!
        ActiveRecord::Base.descendants.each do |model|
          if model.table_name.to_s == table_name.to_s
            matching_model = model
            break
          end
        end
      end

      matching_model
    end

    # For the given attribute, is the underlying database type json (or jsonb)?
    # @param [Arel::Nodes::Node, Arel::Attributes::Attribute] The node to check
    # @return [bool]
    def json_column?(node)
      # we only patched for Arel::Attributes::Attribute, sometimes other nodes (like a grouping) are tested here,
      # hence the safe try call
      return false unless node.respond_to?(:type_caster)

      column_type = node.type_caster.type
      [:json, :jsonb].include?(column_type)
    end

    # Parse association_allowed hashes and arrays to get names.
    # @param [Hash, Array] valid_associations
    # @param [Arel::Table] table
    # @return [Arel::Table, Symbol, Hash] table, field, filter_settings
    def build_associations(valid_associations, table)
      associations = []
      case valid_associations
      when Array
        #! recursive
        more_associations = valid_associations.map { |i| build_associations(i, table) }
        associations.push(*more_associations.flatten.compact) unless more_associations.empty?
      when Hash

        join = valid_associations[:join]
        on = valid_associations[:on]
        available = valid_associations[:available]

        #! recursive
        more_associations = build_associations(valid_associations[:associations], join)
        associations.push(*more_associations.flatten.compact) unless more_associations.empty?

        if available
          associations.push(
            {
              join:,
              on:
            }
          )
        end

      end

      associations
    end

    # Get only the relevant joins
    # @param [ActiveRecord::Base] model
    # @param [Hash] associations
    # @param [Array<Hash>] joins
    # @return [Array<Hash>, Boolean] joins, match
    def build_joins(model, associations, joins = [])
      associations.each do |analysis_job|
        model_join = analysis_job[:join]
        model_on = analysis_job[:on]

        join = { join: model_join, on: model_on }

        return [[join], true] if model == model_join

        next unless analysis_job.include?(:associations)

        assoc = analysis_job[:associations]
        assoc_joins, match = build_joins(model, assoc, joins + [join])

        return [[join] + assoc_joins, true] if match
      end

      [[], false]
    end
  end
end
