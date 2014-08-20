module ModelFilter
  class ParseAst

    # Convert a json post to an arel query.
    # @param [ActiveRecord::Base] model
    # @param [Array<Symbol>] valid_columns
    # @param [Hash] params
    def initialize(model, valid_columns, params)
      # might need this at some point: Rack::Utils.parse_nested_query
      @model = model
      @table = Common.table(model)
      @valid_columns = valid_columns.map(&:to_sym)
      @query_request = CleanParams.perform(params)
    end

    # Convert a json post to an arel query.
    # @return [ActiveRecord::Relation] abstract query matching the params
    def to_query
      query = Common.all_relation(@model)

      filter = @query_request[:filter]
      sort = @query_request[:sort]
      paging = @query_request[:paging]

      query = compose_sort(query, sort) unless sort.blank?
      query = compose_paging(query, paging) unless paging.blank?
      query = compose_filter(query, filter) unless filter.blank?

      query.to_sql
    end

    private

    # Append sorting to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] value
    # @return [ActiveRecord::Relation] the modified query
    def compose_sort(query, value)
      order_by = value_to_sym(value[:order_by], 'order by')
      direction = value_to_sym(value[:direction], 'direction')
      Common.compose_sort(query, @table, order_by, @valid_columns, direction)
    end

    # Append paging to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] value
    # @return [ActiveRecord::Relation] the modified query
    def compose_paging(query, value)
      offset = value_to_sym(value[:offset], 'offset')
      limit = value_to_sym(value[:limit], 'limit')
      Common.compose_paging(query, offset, limit)
    end

    # Append filtering to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] value
    # @return [ActiveRecord::Relation] the modified query
    def compose_filter(query, value)
      conditions = create_conditions(:filter, value)

      conditions.each do |condition|
        query = query.where(condition)
      end

      query
    end

    def create_conditions(field, hash)
      conditions = []
      hash.each do |key, value|
        if key == :range
          # special case for range filter (Hash)
          conditions.push(filter_range(field, value))
        elsif key == :in
          # special case for in filter (Array)
          conditions.push(filter_in(field, value))
        elsif key == :not
          # negation
          conditions.push(*filter_not(value))
        elsif value.is_a?(Hash)
          # recurse
          conditions.push(*create_conditions(key, value))
        elsif value.is_a?(Array) && [:or, :and].include?(key)
          # combine conditions
          conditions.push(filter_combine(key, value))
        else
          # create base condition
          conditions.push(filter_components(field, key, value))
        end

      end

      conditions
    end

    def filter_components(field, filter_name, filter_value)
      case filter_name

        # comparisons
        when :eq, :equal
          Comparison.compose_eq(@table, field, @valid_columns, filter_value)
        when :not_eq, :not_equal
          Comparison.compose_not_eq(@table, field, @valid_columns, filter_value)
        when :lt, :less_than
          Comparison.compose_lt(@table, field, @valid_columns, filter_value)
        when :gt, :greater_than
          Comparison.compose_gt(@table, field, @valid_columns, filter_value)
        when :lteq, :less_than_or_equal
          Comparison.compose_lteq(@table, field, @valid_columns, filter_value)
        when :gteq, :greater_than_or_equal
          Comparison.compose_gteq(@table, field, @valid_columns, filter_value)

        # subsets
        # range is handled separately
        when :interval
          Subset.compose_range_string(@table, field, @valid_columns, filter_value)
        when :in
          Subset.compose_in(@table, field, @valid_columns, filter_value)
        when :contains
          Subset.compose_contains(@table, field, @valid_columns, filter_value)
        when :starts_with
          Subset.compose_starts_with(@table, field, @valid_columns, filter_value)
        when :ends_with
          Subset.compose_ends_with(@table, field, @valid_columns, filter_value)
        #when :regex - not implemented in Arel 3.
        #  Subset.compose_regex(@table, field, @valid_columns, filter_value)

        else
          fail ArgumentError, "Unrecognised filter #{filter_name}."
      end
    end

    def filter_combine(filter_name, filter_value)

      conditions = []
      filter_value.each do |item|
        new_conditions = create_conditions(filter_name, item)
        conditions.push(*new_conditions)
      end

      condition_builder = nil
      conditions.each do |condition|
        if condition_builder.blank?
          condition_builder = condition

        else
          case filter_name
            when :and
              condition_builder = Common.compose_and(condition_builder, condition)
            when :or
              condition_builder = Common.compose_or(condition_builder, condition)
            else
              fail ArgumentError, "Unrecognised filter combiner #{filter_name}."
          end

        end
      end

      condition_builder
    end

    def filter_range(field, filter_value)
      from = filter_value[:from]
      to = filter_value[:to]
      interval = filter_value[:interval]

      if !from.blank? && !to.blank? && !interval.blank?
        fail ArgumentError, "Range filter must use either 'from' and 'to' or 'interval', not both."
      elsif from.blank? && !to.blank?
        fail ArgumentError, "Range filter missing 'from'."
      elsif !from.blank? && to.blank?
        fail ArgumentError, "Range filter missing 'to'."
      elsif !from.blank? && !to.blank?
        Subset.compose_range(@table, field, @valid_columns, from, to)
      elsif !interval.blank?
        Subset.compose_range_string(@table, field, @valid_columns, interval)
      else
        fail ArgumentError, 'Range filter was not valid.'
      end
    end

    def filter_in(field, filter_value)
      Subset.compose_in(@table, field, @valid_columns, filter_value)
    end

    def filter_not(value)
      conditions_to_negate = []
      value.each do |item|
        new_conditions = create_conditions(:not, item)
        conditions_to_negate.push(*new_conditions)
      end

      conditions = []

      conditions_to_negate.each do |condition|
        conditions.push(Common.compose_not(condition))
      end

      conditions
    end

    def value_to_sym(value, description)
      fail ArgumentError, "#{description} must have a value." if value.blank?
      value.respond_to?(:to_sym) ? value.to_sym : value
    end
  end
end

=begin

Sample json

{
    "filter": {
        "site_id": {
            "less_than": "123456",
            "greater_than": "012345",
            "in": [
                1,
                2,
                3
            ],
            "range": {
                "from": 100,
                "to": 200
            }
        },
        "notes": {
            "greater_than_or_equal": "012345",
            "contains": "contain text",
            "starts_with": "starts with text",
            "ends_with": "ends with text",
            "range": {
                "interval": "[123,128]"
            }
        },
        "or": [
            {
                "recorded_date": {
                    "contains": "Hello"
                }
            },
            {
                "file_hash": {
                    "ends_with": "world"
                }
            },
            {
                "duration_seconds": {
                    "eq": 60,
                    "lteq": 70
                }
            },
            {
                "duration_seconds": {
                    "equal": 50,
                    "gteq": 80
                }
            }
        ],
        "and": [
            {
                "duration_seconds": {
                    "not_eq": 40
                }
            },
            {
                "channels": {
                    "eq": 2,
                    "less_than_or_equal": "012345"
                }
            }
        ],
        "not": [
            {
                "duration_seconds": {
                    "not_eq": 140
                }
            },
            {
                "channels": {
                    "eq": 1,
                    "less_than_or_equal": "54321"
                }
            }
        ]
    },
    "sort": {
        "orderBy": "duration_seconds",
        "direction": "desc"
    },
    "paging": {
        "offset": 0,
        "limit": 10,
        "next": "http://host.domain/resource?offset=1&limit=10",
        "previous": "http://host.domain/resource?offset=1&limit=10"
    }
}

=end