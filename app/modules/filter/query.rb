# frozen_string_literal: true

module Filter
  # Construct a query using Arel.
  class Query
    include Comparison
    include Core
    include Subset
    include Projection
    include Parse
    include Validate
    include Custom

    attr_reader :key_prefix, :max_items, :initial_query, :table,
      :valid_fields, :text_fields, :filter_settings,
      :parameters, :filter, :projection, :qsp_text_filter,
      :qsp_generic_filters, :paging, :sorting, :build,
      :custom_fields2, :capabilities

    # Convert a json POST body to an arel query.
    # @param [Hash] parameters
    # @param [ActiveRecord::Relation] query
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    def initialize(parameters, query, model, filter_settings)
      # might need this at some point: Rack::Utils.parse_nested_query
      @key_prefix = 'filter_'
      key_partial_match = :filter_partial_match

      @default_page = 1
      @default_items = 25
      @max_items = 500
      @table = relation_table(model)

      # `.all' adds 'id' to the select!!
      @initial_query = !query.nil? && query.is_a?(ActiveRecord::Relation) ? query : relation_all(model)
      # the check for an active record relation above can lead to some subtle
      # bugs when you pass some non-nil query like thing.
      # temporarily throwing here to see what breaks. All tests pass so
      # we'll make the check below a validation that always runs
      unless query.is_a?(ActiveRecord::Relation)
        raise ArgumentError, "query was not an ActiveRecord::Relation. Query: #{query}"
      end

      validate_filter_settings(filter_settings)
      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @text_fields = filter_settings.include?(:text_fields) ? filter_settings[:text_fields].map(&:to_sym) : []
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      @filter_settings = filter_settings
      @default_sort_order = filter_settings[:defaults][:order_by]
      @default_sort_direction = filter_settings[:defaults][:direction]
      @custom_fields2 = filter_settings[:custom_fields2] || {}
      @capabilities = filter_settings[:capabilities] || {}

      @build = Build.new(@table, filter_settings)

      @parameters = CleanParams.perform(parameters)
      validate_hash(@parameters)

      @parameters = decode_payload(@parameters)

      @filter = @parameters.include?(:filter) && !@parameters[:filter].blank? ? @parameters[:filter] : {}
      @projection = parse_projection(@parameters)

      # remove key_partial_match key from parameters hash
      parameters_for_generic = @parameters.dup
      parameters_for_generic.delete(key_partial_match) if parameters_for_generic.include?(key_partial_match)

      # merge filters from qsp partial text match into POST body filter
      partial_match_filters = parse_qsp_partial_match_text(@parameters, key_partial_match, @text_fields)
      @filter = add_qsp_to_filter(@filter, partial_match_filters, :or)

      # merge filters from qsp generic equality match into POST body filter
      qsp_generic_filters = parse_qsp(nil, parameters_for_generic, key_prefix)
      @filter = add_qsp_to_filter(@filter, qsp_generic_filters, :and)

      # populate properties with qsp filter spec
      @qsp_text_filter = @parameters[key_partial_match]
      @qsp_generic_filters = {}
      qsp_generic_filters.each do |key, value|
        @qsp_generic_filters[key] = value[:eq]
      end

      @paging = parse_paging(@parameters, @default_page, @default_items, @max_items)
      @sorting = parse_sorting(@parameters, @default_sort_order, @default_sort_direction)
    end

    # Get the query represented by the parameters sent in new.
    # @return [ActiveRecord::Relation] query
    def query_full
      query = @initial_query.dup

      # restrict to select columns
      query = query_projection(query)

      #filter
      query = query_filter(query)

      # sorting
      query = query_sort(query)

      # paging
      query_paging(query)
    end

    # Get the query represented by the parameters sent in new. DOES NOT include paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_paging_sorting
      query = @initial_query.dup

      # restrict to select columns
      query = query_projection(query)

      #filter
      query_filter(query)
    end

    # Get the query represented by the parameters sent in new. DOES NOT include advanced filtering, paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_filter_paging_sorting
      query = @initial_query.dup

      # restrict to select columns
      query_projection(query)
    end

    # Add filtering to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_filter(query)
      if has_filter_params?
        conditions = @build.parse(@filter)
        apply_conditions(query, conditions)
      else
        query
      end
    end

    # Add projections to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_projection(query)
      if has_projection_params?
        apply_projections(query, @build.projections(@projection))
      else
        query_projection_default(query)
      end
    end

    # Add default projections to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_projection_default(query)
      apply_projections(query, @build.projections({ include: @render_fields }))
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_sort(query)
      return query unless has_sort_params?

      apply_sort(query, @table, @sorting[:order_by], @valid_fields, @sorting[:direction])
    end

    # Add paging to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_paging(query)
      return query unless has_paging_params?
      return query if is_paging_disabled?

      apply_paging(query, @paging[:offset], @paging[:limit])
    end

    # Add paging to query.
    # @param [::ActiveRecord::Relation] query
    # @param [Integer] offset
    # @param [Integer] limit
    # @return [ActiveRecord::Relation] query
    def query_paging_custom(query, offset, limit)
      apply_paging(query, offset, limit)
    end

    def has_paging_params?
      !@paging[:page].blank? && !@paging[:items].blank?
    end

    def is_paging_disabled?
      @paging[:disable_paging] == 'true' || @paging[:disable_paging] == true
    end

    def has_sort_params?
      !@sorting[:order_by].blank? && !@sorting[:direction].blank?
    end

    def has_projection_params?
      !@projection.blank?
    end

    def has_filter_params?
      !@filter.blank?
    end

    private

    def decode_payload(parameters)
      return parameters unless parameters.include?(:filter_encoded)

      parameters.extract!(:filter_encoded) => {filter_encoded: value}

      return parameters if value.blank?

      json = begin
        Base64.urlsafe_decode64(value)
      rescue StandardError
        raise CustomErrors::FilterArgumentError, 'filter_encoded was not a valid RFC 4648 base64url string'
      end

      hash = begin
        JSON.parse(json)
      rescue StandardError => e
        # JSON parser returns line where the error occurred in the C source code...
        # so basically useless. Remove it.
        message = e.message.gsub(/\d+: /, '')
        error = "filter_encoded was not a valid JSON payload: #{message}." \
                "Check the filter is valid JSON and it was not truncated. We received value of size #{value.length}."
        raise CustomErrors::FilterArgumentError, error
      end

      # parameters has already been cleaned, but hash has just been deserialized!
      # so clean and normalize names here too
      hash = CleanParams.perform(hash)

      parameters.deep_merge!(hash)

      parameters
    end

    # Add qsp spec to filter
    # @param [Hash,Array] filter
    # @param [Hash] additional
    # @param [Symbol] combiner
    # @return [Hash,Array]
    def add_qsp_to_filter(filter, additional, combiner)
      raise 'Additional filter items must be a hash.' unless additional.is_a?(Hash)
      raise 'Filter must be a hash or array.' unless filter.is_a?(Hash) || filter.is_a?(Array)
      raise 'Combiner should not be blank.' if combiner.blank? || !combiner.is_a?(Symbol)

      # don't do anything unless we need to
      #return filter if additional.size.zero?

      # normalize a root filter array
      filter = { and: filter } if filter.is_a?(Array)

      # return a merge of existing filter and qsp filters
      # {
      #   combiner => [
      #     filter,
      #     additional
      #   ]
      # }

      more_than_one = additional.size > 1
      combiner_present = filter.include?(combiner)
      item_without_combiner_exists = filter.keys.any? { |k| ![:and, :or, :not].include?(k) }

      additional.each do |key, value|
        match_at_top = filter.include?(key)
        match_in_combiner = combiner_present && filter[combiner].include?(key)

        if match_at_top
          filter[key].merge!(value)
        elsif match_in_combiner
          filter[combiner][key].merge!(value)
        elsif !more_than_one && !combiner_present
          filter[key] = value
        elsif more_than_one && !combiner_present && !item_without_combiner_exists
          filter[combiner] = {} unless filter.include?(combiner)
          filter[combiner][key] = value
        elsif combiner_present && combiner != :and
          filter[combiner][key] = value
        elsif item_without_combiner_exists && combiner == :and
          filter[key] = value
        else
          raise 'Problem adding additional filter items.'
        end
      end

      filter
    end

    # Add conditions to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [ActiveRecord::Relation] the modified query
    def apply_conditions(query, conditions)
      conditions.each do |condition_or_hash|
        case condition_or_hash
        in {transforms:, node:}
          apply_condition(apply_transforms(query, transforms), node)
        in ::Arel::Nodes::Node => condition
          apply_condition(query, condition)
        end => query
      end
      query
    end

    # Add condition to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Arel::Nodes::Node] condition
    # @return [ActiveRecord::Relation] the modified query
    def apply_condition(query, condition)
      validate_query(query)
      validate_condition(condition)
      query.where(condition)
    end

    # Apply a series of transforms to the current query
    def apply_transforms(query, transforms)
      transforms.reduce(query) do |q, transform|
        transform.call(q)
      end
    end

    # Add joins to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<String>] joins
    # @return [ActiveRecord::Relation] the modified query
    def apply_joins(query, joins)
      joins.each do |join|
        query = apply_join(query, join)
      end
      query
    end

    # Add join to a query.
    # @param [ActiveRecord::Relation] query
    # @param [String] join
    # @return [ActiveRecord::Relation] the modified query
    def apply_join(query, join)
      validate_query(query)
      query.joins(join)
    end

    # Append sorting to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] allowed
    # @param [Symbol] direction
    # @return [ActiveRecord::Relation] the modified query
    def apply_sort(query, table, column_name, allowed, direction)
      validate_query_table_column(query, table, column_name, allowed)
      validate_sorting(column_name, allowed, direction)

      # allow sorting by field mappings
      sort_field = @build.build_custom_calculated_field(column_name)&.fetch(:arel)
      sort_field = table[column_name] if sort_field.blank?

      if sort_field.is_a? String
        sort_field
      elsif direction == :desc
        Arel::Nodes::Descending.new(sort_field)
      else
        #direction == :asc
        Arel::Nodes::Ascending.new(sort_field)
      end => sort_field_by

      query.order(sort_field_by)
    end

    # Append paging to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Integer] offset
    # @param [Integer] limit
    # @return [ActiveRecord::Relation] the modified query
    def apply_paging(query, offset, limit)
      validate_paging(offset, limit)
      query.offset(offset).limit(limit)
    end
  end
end
