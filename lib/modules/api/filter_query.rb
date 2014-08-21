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