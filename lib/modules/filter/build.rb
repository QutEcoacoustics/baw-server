module Filter

  # Provides support for parsing a filter from a hash to build a query.
  class Build
    include Comparison
    include Core
    include Custom
    include Projection
    include Subset
    include Validate

    # Create an instance of Build.
    # @param [Arel::Table] table
    # @param [Hash] filter_settings
    # @return [void]
    def initialize(table, filter_settings)
      @table = table
      @filter_settings = filter_settings

      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @text_fields = filter_settings[:text_fields].map(&:to_sym)
      @valid_associations = filter_settings[:valid_associations]

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
          :regex
      ]
    end

    # Build projections from a hash.
    # @param [Hash] hash
    # @return [Array<Arel::Attributes::Attribute>] projections
    def projections(hash)
      fail CustomErrors::FilterArgumentError.new("Projections hash must have exactly 1 entry, got #{hash.size}.", {hash: hash}) if hash.blank? || hash.size != 1
      result = []
      hash.each do |key, value|
        fail CustomErrors::FilterArgumentError.new("Must be 'include' or 'exclude' at top level, got #{key}", {hash: hash}) unless [:include, :exclude].include?(key)
        result = projection(key, value)
      end
      result
    end

    # Build projection to include or exclude.
    # @param [Symbol] key
    # @param [Hash<Symbol>] value
    # @return [Array<Arel::Attributes::Attribute>] projections
    def projection(key, value)
      fail CustomErrors::FilterArgumentError.new('Must not contain duplicate fields.', {"#{key}" => value}) if !value.blank? && value.uniq.length != value.length

      columns = []
      case key
        when :include
          fail CustomErrors::FilterArgumentError.new('Include must contain at least one field.') if value.blank?
          columns = value.map { |x| CleanParams.clean(x) }
        when :exclude
          fail CustomErrors::FilterArgumentError.new('Exclude must contain at least one field.') if value.blank?
          columns = @valid_fields.reject { |item| value.include?(item) }.map { |x| CleanParams.clean(x) }
          fail CustomErrors::FilterArgumentError.new('Exclude must contain at least one field.') if columns.blank?
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised projection key #{key}.")
      end

      columns.map { |item|
        project_column(@table, item, @valid_fields)
      }
    end

    # Combine two conditions.
    # @param [Symbol] combiner
    # @param [Arel::Nodes::Node] condition1
    # @param [Arel::Nodes::Node] condition2
    # @return [Arel::Nodes::Node] condition
    def combiner_two(combiner, condition1, condition2)
      case combiner
        when :and
          compose_and(condition1, condition2)
        when :or
          compose_or(condition1, condition2)
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised filter combiner #{combiner}.")
      end
    end

    # Combine conditions.
    # @param [Symbol] combiner
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [Arel::Nodes::Node] condition
    def combiner_one(combiner, conditions)
      fail CustomErrors::FilterArgumentError.new("Combiner '#{combiner}' must have at least 2 entries, got #{conditions.size}.") if conditions.blank? || conditions.size < 2
      combined_conditions = nil

      conditions.each do |condition|

        if combined_conditions.blank?
          combined_conditions = condition
        else
          combined_conditions = combiner_two(combiner, combined_conditions, condition)
        end

      end

      combined_conditions
    end

    # Build a text condition.
    # @param [String] text
    # @return [Arel::Nodes::Node] condition
    def contains_text(text)
      conditions = []
      @text_fields.each do |text_field|
        condition = compose_contains(@table, text_field, @valid_fields, text)
        conditions.push(condition)
      end

      if conditions.size > 1
        combiner_one(:or, conditions)
      else
        conditions[0]
      end
    end

    # Build an equality condition that matches specified value to specified fields.
    # @param [Hash] filter_hash
    # @return [Arel::Nodes::Node] condition
    def generic_equals(filter_hash)
      conditions = []
      filter_hash.each do |key, value|
        conditions.push(compose_eq(@table, key, @valid_fields, value))
      end

      if conditions.size > 1
        combiner_one(:and, conditions)
      else
        conditions[0]
      end

    end

    # Parse a filter hash.
    # @param [Hash] filter_hash
    # @return [Hash]
    def parse(filter_hash)
      conditions, joins = parse_filter(filter_hash)

      # using .where in Rails will do 'AND' by default
      #final_conditions = combiner_one(:and, conditions)

      # add joins to final_conditions
      join_sql = []
      joins.each do |j|
        left_outer_join = AudioRecording.arel_table.join(j[:join].arel_table, Arel::Nodes::OuterJoin).on(j[:on])
        sources = left_outer_join.join_sources
        fail CustomErrors::FilterArgumentError.new("SQL contained more than one join: #{sources}") if sources.size != 1
        join_sql.push(sources[0].to_sql)
      end

      [conditions, join_sql]
    end

    private

    def parse_filter(primary, secondary = nil, extra = nil, joins = [])

      if primary.is_a?(Hash)
        fail CustomErrors::FilterArgumentError.new("Filter hash must have at least 1 entry, got #{primary.size}.", {hash: primary}) if primary.blank? || primary.size < 1
        fail CustomErrors::FilterArgumentError.new("Extra must be null when processing a hash, got #{extra}.", {hash: primary}) unless extra.blank?

        conditions = []

        primary.each do |key, value|
          condition, joins = parse_filter(key, value, secondary, joins)
          if condition.is_a?(Array)
            conditions.push(*condition)
          else
            conditions.push(condition)
          end
        end

        [conditions, joins]

      elsif primary.is_a?(Symbol)

        case primary
          when :and, :or
            combiner = primary
            filter_hash = secondary
            condition, joins = parse_filter(filter_hash, nil, nil, joins)
            [combiner_one(combiner, condition), joins]
          when :not
            #combiner = primary
            filter_hash = secondary
            condition, joins = parse_filter(filter_hash, nil, nil, joins)

            if condition.respond_to?(:map)
              negated_conditions = condition.map { |c| compose_not(c) }
            else
              negated_conditions = [compose_not(condition)]
            end

            [negated_conditions, joins]
          when *@valid_fields.dup.push(/\./)
            field = primary
            field_conditions = secondary
            info = parse_table_field(@table, field, @filter_settings)
            condition, joins = parse_filter(field_conditions, info, nil, joins)
            [condition, joins]
          when *@valid_conditions
            filter_name = primary
            filter_value = secondary
            info = extra

            table = info[:arel_table]
            column_name = info[:field_name]
            model = info[:model]
            valid_fields = info[:filter_settings][:valid_fields]

            # add join table to joins array if necessary
            additional_joins, match = build_joins(model, @valid_associations)

            current_models = joins.map { |j| j[:join]}
            new_joins = additional_joins.select { |j| !current_models.include?(j[:join]) }
            joins.push(*new_joins)

            [condition(filter_name, table, column_name, valid_fields, filter_value), joins]
          else
            fail CustomErrors::FilterArgumentError.new("Unrecognised combiner or field name: #{primary}.")
        end
      else
        fail CustomErrors::FilterArgumentError.new("Unrecognised filter component: #{primary}.")
      end
    end

    # Build a condition.
    # @param [Symbol] filter_name
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<symbol>] valid_fields
    # @param [Object] filter_value
    # @return [Arel::Nodes::Node] condition
    def condition(filter_name, table, column_name, valid_fields, filter_value)
      case filter_name

        # comparisons
        when :eq, :equal
          compose_eq(table, column_name, valid_fields, filter_value)
        when :not_eq, :not_equal
          compose_not_eq(table, column_name, valid_fields, filter_value)
        when :lt, :less_than
          compose_lt(table, column_name, valid_fields, filter_value)
        when :not_lt, :not_less_than
          compose_not_lt(table, column_name, valid_fields, filter_value)
        when :gt, :greater_than
          compose_gt(table, column_name, valid_fields, filter_value)
        when :not_gt, :not_greater_than
          compose_not_gt(table, column_name, valid_fields, filter_value)
        when :lteq, :less_than_or_equal
          compose_lteq(table, column_name, valid_fields, filter_value)
        when :not_lteq, :not_less_than_or_equal
          compose_not_lteq(table, column_name, valid_fields, filter_value)
        when :gteq, :greater_than_or_equal
          compose_gteq(table, column_name, valid_fields, filter_value)
        when :not_gteq, :not_greater_than_or_equal
          compose_not_gteq(table, column_name, valid_fields, filter_value)

        # subsets
        when :range, :in_range
          compose_range_options(table, column_name, valid_fields, filter_value)
        when :not_range, :not_in_range
          compose_not_range_options(table, column_name, valid_fields, filter_value)
        when :in
          compose_in(table, column_name, valid_fields, filter_value)
        when :not_in
          compose_not_in(table, column_name, valid_fields, filter_value)
        when :contains, :contain
          compose_contains(table, column_name, valid_fields, filter_value)
        when :not_contains, :not_contain, :does_not_contain
          compose_not_contains(table, column_name, valid_fields, filter_value)
        when :starts_with, :start_with
          compose_starts_with(table, column_name, valid_fields, filter_value)
        when :not_starts_with, :not_start_with, :does_not_start_with
          compose_not_starts_with(table, column_name, valid_fields, filter_value)
        when :ends_with, :end_with
          compose_ends_with(table, column_name, valid_fields, filter_value)
        when :not_ends_with, :not_end_with, :does_not_end_with
          compose_not_ends_with(table, column_name, valid_fields, filter_value)
        when :regex
          compose_regex(table, column_name, valid_fields, filter_value)

        # unknown
        else
          fail CustomErrors::FilterArgumentError.new("Unrecognised filter #{filter_name}.")
      end
    end


    # Build table field from field symbol.
    # @param [Arel::Table] table
    # @param [Symbol] field
    # @param [Hash] filter_settings
    # @return [Arel::Table, Symbol, Hash] table, field, filter_settings
    def parse_table_field(table, field, filter_settings)
      validate_table(table)
      fail CustomErrors::FilterArgumentError, 'Field name must be a symbol.' unless field.is_a?(Symbol)
      validate_filter_settings(filter_settings)

      field_s = field.to_s

      if field_s.include?('.')
        dot_index = field.to_s.index('.')
        parsed_table = field[0, dot_index].to_sym
        parsed_field = field[(dot_index + 1)..field.length].to_sym

        associations = build_associations(@valid_associations, table)
        models = associations.map { |a| a[:join] }
        table_names = associations.map { |a| a[:join].table_name.to_sym }

        validate_name(parsed_table, table_names)

        model = parsed_table.to_s.classify.constantize

        validate_association(model, models)

        model_filter_settings = model.filter_settings
        model_valid_fields = model_filter_settings[:valid_fields].map(&:to_sym)
        arel_table = relation_table(model)

        validate_table_column(arel_table, parsed_field, model_valid_fields)

        {
            table_name: parsed_table,
            field_name: parsed_field,
            arel_table: arel_table,
            model: model,
            filter_settings: model_filter_settings
        }
      else
        {
            table_name: table.name,
            field_name: field,
            arel_table: table,
            model: table.name.to_s.classify.constantize,
            filter_settings: filter_settings
        }
      end

    end

    # Parse association_allowed hashes and arrays to get names.
    # @param [Hash, Array] valid_associations
    # @param [Arel::Table] table
    # @return [Arel::Table, Symbol, Hash] table, field, filter_settings
    def build_associations(valid_associations, table)

      associations = []
      if valid_associations.is_a?(Array)
        more_associations = valid_associations.map { |i| build_associations(i, table) }
        associations.push(*more_associations.flatten.compact) if more_associations.size > 0
      elsif valid_associations.is_a?(Hash)

        join = valid_associations[:join]
        on = valid_associations[:on]
        available = valid_associations[:available]

        more_associations = build_associations(valid_associations[:associations], join)
        associations.push(*more_associations.flatten.compact) if more_associations.size > 0

        if available
          associations.push(
              {
                  join: join,
                  on: on
              })
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

      associations.each do |a|
        model_join = a[:join]
        model_on = a[:on]

        join = {join: model_join, on: model_on}

        return [[join], true] if model == model_join

        if a.include?(:associations)
          assoc = a[:associations]
          assoc_joins, match = build_joins(model, assoc, joins + [join])

          return [[join] + assoc_joins, true] if match
        end

      end

      [[], false]
    end

  end
end