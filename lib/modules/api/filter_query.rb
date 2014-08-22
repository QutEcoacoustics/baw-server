module Api
  class FilterQuery
    include FilterComparison
    include FilterCore
    include FilterSubset
    include FilterParse
    include Validate

    # Convert a json POST body to an arel query.
    # @param [Hash] parameters
    # @param [ActiveRecord::Base] model
    # @param [Array<Symbol>] valid_fields
    # @param [Array<Symbol>] text_fields
    def initialize(parameters, model, valid_fields = [], text_fields = [])
      # might need this at some point: Rack::Utils.parse_nested_query
      @model = model
      @table = relation_table(model)
      @valid_fields = valid_fields.map(&:to_sym)
      @text_fields = text_fields.map(&:to_sym)

      @parameters = CleanParams.perform(parameters)
      validate_hash(@parameters)

      @key_prefix = 'filter_'
    end

    def get_paging
      parse_paging(@parameters)
    end

    def get_sort
      parse_sort(@parameters)
    end

    # Convert a hash to a query. Includes sorting and paging.
    # @return [ActiveRecord::Relation] query
    def query_full
      query = relation_all(@model)

      #filter
      query = query_base(query)

      # sorting
      query = query_sort(query)

      # paging
      query = query_paging(query)

      # add qsp text filters
      query = query_filter_text(query)

      # add qsp generic_filters
      query = query_filter_generic(query)

      # result
      query
    end

    # Convert a hash to a query. DOES NOT include paging.
    # @return [ActiveRecord::Relation] query
    def query_without_paging
      query = relation_all(@model)

      #filter
      query = query_base(query)

      # sorting
      query = query_sort(query)

      # add qsp text filters
      query = query_filter_text(query)

      # add qsp generic_filters
      query = query_filter_generic(query)

      # result
      query
    end

    # Add filtering to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_base(query)
      validate_query(query)
      filter = @parameters[:filter]
      filter = {} if filter.blank?
      add_conditions(query, build_conditions(:filter, filter, @table, @valid_fields))
    end

    # Add text filter to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_filter_text(query)
      validate_query(query)
      qsp_text_filter = parse_qsp_text(@parameters)
      unless qsp_text_filter.blank?
        text_condition = build_text(qsp_text_filter, @text_fields, @table, @valid_fields)
        query = add_condition(query, text_condition)
      end
      query
    end

    # Add text filter to a query.
    # @param [ActiveRecord::Relation] query
    # @param [String] filter_text
    # @return [ActiveRecord::Relation] query
    def query_filter_text_custom(query, filter_text)
      text_condition = build_text(filter_text, @text_fields, @table, @valid_fields)
      add_condition(query, text_condition)
    end

    # Add generic equality filters to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_filter_generic(query)
      validate_query(query)
      qsp_generic_filters = parse_qsp(nil, @parameters, @key_prefix, @valid_fields)
      unless qsp_generic_filters.blank?
        query = add_condition(query, build_generic(qsp_generic_filters, @table, @valid_fields))
      end
      query
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_sort(query)
      validate_query(query)
      build_sort(query, @parameters)
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @param [Symbol, String] order_by
    # @param [Symbol, String] direction
    # @return [ActiveRecord::Relation] query
    def query_sort_custom(query, order_by, direction)
      compose_sort(query, @table, order_by, @valid_fields, direction)
    end

    # Add paging to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_paging(query)
      validate_query(query)
      build_paging(query, @parameters)
    end

    # Add paging to query.
    # @param [ActiveRecord::Relation] query
    # @param [Integer] offset
    # @param [Integer] limit
    # @return [ActiveRecord::Relation] query
    def query_paging_custom(query, offset = 0, limit = validate_max_items)
      compose_paging(query, offset, limit)
    end
  end
end