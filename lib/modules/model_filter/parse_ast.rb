module ModelFilter
  class ParseAst

    # Convert a json POST body to an arel query.
    # @param [ActiveRecord::Base] model
    # @param [Hash] params
    # @param [Array<Symbol>] valid_fields
    # @param [Array<Symbol>] text_fields
    def initialize(model, params, valid_fields = [], text_fields = [])
      # might need this at some point: Rack::Utils.parse_nested_query
      @model = model
      @table = Common.table(model)
      @valid_fields = valid_fields.map(&:to_sym)
      @text_fields = text_fields.map(&:to_sym)
      @query_request = CleanParams.perform(params)

      @specified_field_equals = 'filter_'
    end

    def custom_query(offset = 0, limit = 10, order_by, direction, filter_text, filter_hash)
      query = Common.all_relation(@model)
      request_params = @query_request

      # sorting
      Common.compose_sort(query, @table, order_by, @valid_fields, direction)

      # paging
      Common.compose_paging(query, offset, limit)

      # filter
      filter = request_params[:filter]
      filter = {} if filter.blank?
      add_conditions(query, create_conditions(:filter, filter))

      # add text filter
      add_conditions(query, build_qsp_text_filter(filter_text))

      # add generic filters
      add_conditions(query, build_qsp_generic_filter(filter_hash))

      # result
      query
    end

    # Convert a json post to an arel query.
    # @return [ActiveRecord::Relation] abstract query matching the params
    def query
      query = Common.all_relation(@model)
      request_params = @query_request

      # sorting
      query = compose_sort(query, request_params)

      # paging
      query = compose_paging(query, request_params)

      # filter
      filter = request_params[:filter]
      filter = {} if filter.blank?
      add_conditions(query, create_conditions(:filter, filter))

      # add qsp text filters
      qsp_text_filter = text_qsp_filter(request_params)
      unless qsp_text_filter.blank?
        add_conditions(query, build_qsp_text_filter(qsp_text_filter))
      end

      # add qsp generic_filters
      qsp_generic_filters = qsp_filter_perform(nil, request_params)
      unless qsp_generic_filters.blank?
        add_conditions(query, build_qsp_generic_filter(qsp_generic_filters))
      end

      # result
      query
    end

    private

    # Append sorting to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] params
    # @return [ActiveRecord::Relation] the modified query
    def compose_sort(query, params)
      # qsp
      order_by = params[:order_by]
      direction = params[:direction]

      # POST body
      order_by = params[:sort][:order_by] if order_by.blank? && !params[:sort].blank?
      direction = params[:sort][:direction] if order_by.blank? && !params[:sort].blank?

      # default to reverse chronological
      order_by = :recorded_date if order_by.blank?
      direction = :desc if direction.blank?

      Common.compose_sort(query, @table, order_by, @valid_fields, direction)
    end

    # Append paging to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] params
    # @return [ActiveRecord::Relation] the modified query
    def compose_paging(query, params)
      # qsp
      offset = params[:offset]
      limit = params[:limit]

      # POST body
      offset = params[:paging][:offset] if offset.blank? && !params[:paging].blank?
      limit = params[:paging][:limit] if limit.blank? && !params[:paging].blank?

      # default to first page with 50 per age
      offset = 0 if offset.blank?
      limit = 50 if limit.blank?

      Common.compose_paging(query, offset, limit)
    end

    # Add conditions to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [ActiveRecord::Relation] the modified query
    def add_conditions(query, conditions)
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
          Comparison.compose_eq(@table, field, @valid_fields, filter_value)
        when :not_eq, :not_equal
          Comparison.compose_not_eq(@table, field, @valid_fields, filter_value)
        when :lt, :less_than
          Comparison.compose_lt(@table, field, @valid_fields, filter_value)
        when :gt, :greater_than
          Comparison.compose_gt(@table, field, @valid_fields, filter_value)
        when :lteq, :less_than_or_equal
          Comparison.compose_lteq(@table, field, @valid_fields, filter_value)
        when :gteq, :greater_than_or_equal
          Comparison.compose_gteq(@table, field, @valid_fields, filter_value)

        # subsets
        # range is handled separately
        when :interval
          Subset.compose_range_string(@table, field, @valid_fields, filter_value)
        when :in
          Subset.compose_in(@table, field, @valid_fields, filter_value)
        when :contains
          Subset.compose_contains(@table, field, @valid_fields, filter_value)
        when :starts_with
          Subset.compose_starts_with(@table, field, @valid_fields, filter_value)
        when :ends_with
          Subset.compose_ends_with(@table, field, @valid_fields, filter_value)
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

      filter_combine_builder(filter_name, conditions)
    end

    def filter_combine_builder(filter_name, conditions)
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
        Subset.compose_range(@table, field, @valid_fields, from, to)
      elsif !interval.blank?
        Subset.compose_range_string(@table, field, @valid_fields, interval)
      else
        fail ArgumentError, 'Range filter was not valid.'
      end
    end

    def filter_in(field, filter_value)
      Subset.compose_in(@table, field, @valid_fields, filter_value)
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

    # add a text filter to all applicable fields
    def build_qsp_text_filter(text)
      conditions = []
      @text_fields.each do |text_field|
        conditions.push(Subset.compose_contains(@table, text_field, @valid_fields, text))
      end

      filter_combine_builder(:or, conditions)
    end

    # add an equality filter match specified value to specified fields
    def build_qsp_generic_filter(filter_hash)
      conditions = []
      filter_hash.each do |key, value|
        conditions.push(filter_components(key, :eq, value))
      end

      filter_combine_builder(:and, conditions)
    end

    def text_qsp_filter(params)
      text_field_contains = :filter_partial_match

      if params[text_field_contains].blank?
        nil
      else
        params[text_field_contains]
      end
    end

    # Get the QSPs from an object.
    # @param [Object] obj
    # @param [Object] value
    # @return [Hash] Matching entries
    def qsp_filter_perform(obj, value, found = {})
      if value.is_a?(Hash)
        found = qsp_filter_hash(value, found)
      elsif value.is_a?(Array)
        found = qsp_filter_array(obj, value, found)
      else
        key_s = obj.blank? ? '' : obj.to_s
        is_filter_qsp = key_s.starts_with?(@specified_field_equals)

        if is_filter_qsp
          new_key = key_s[@specified_field_equals.size..-1].to_sym
          found[new_key] = value if @valid_fields.include?(new_key)
        end
      end
      found
    end

    # Get the QSPs from a hash.
    # @param [Hash] hash
    # @param [Hash] found
    # @return [Hash] Matching entries
    def qsp_filter_hash(hash, found)
      hash.each do |key, value|
        found = qsp_filter_perform(key, value, found)
      end
      found
    end

    # get a cleaned Array
    # @param [Object] key
    # @param [Array] array
    # @param [Hash] found
    # @return [Hash] Matching entries
    def qsp_filter_array(key, array, found)
      array.each do |item|
        found = qsp_filter_perform(key, item, found)
      end
      found
    end

  end
end

=begin

Sample POST url and json body

POST /audio_recordings/filter?filter_notes=hello&filter_partial_match=testing_testing
POST /audio_recordings/filter?filter_notes=hello&filter_channels=28&filter_partial_match=testing_testing

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