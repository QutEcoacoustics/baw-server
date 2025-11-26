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
    include Archivable

    DEFAULT_PAGE_NUMBER = 1
    DEFAULT_PAGE_ITEMS = 25
    DEFAULT_PAGE_MAX_ITEMS = 500
    DEFAULT_PAGING = {
      offset: 0,
      limit: DEFAULT_PAGE_ITEMS,
      page: DEFAULT_PAGE_NUMBER,
      items: DEFAULT_PAGE_ITEMS,
      disable_paging: false
    }.freeze

    attr_reader :key_prefix, :max_items, :initial_query, :table,
      :valid_fields, :text_fields, :filter_settings,
      :parameters, :filter, :projection, :qsp_text_filter,
      :qsp_generic_filters, :paging, :sorting, :build,
      :custom_fields2

    # The fields actually requested by any projection (default or not)
    # after flattening. If projection was not requested this will be equivalent to `render_fields`.
    # Nil if `query_projection` was not called.
    # @return [Set<Symbol>]
    attr_reader :projected_fields

    # Returns the filter provided by a request, before being merged onto the default filter
    # @return [Hash] filter
    attr_reader :supplied_filter

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
      @model = model
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

      reraise_as_internal_error do
        validate_filter_settings(filter_settings)
      end
      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @text_fields = filter_settings.include?(:text_fields) ? filter_settings[:text_fields].map(&:to_sym) : []
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      @filter_settings = filter_settings
      @default_sort_order = filter_settings[:defaults][:order_by]
      @default_sort_direction = filter_settings[:defaults][:direction]
      @default_filter = filter_settings[:defaults].fetch(:filter, nil)
      @custom_fields2 = filter_settings[:custom_fields2] || {}
      set_archived_param(parameters)

      @build = Build.new(@table, filter_settings)

      @parameters = CleanParams.perform(parameters)
      validate_hash(@parameters)

      @parameters = decode_payload(@parameters)

      @supplied_filter = @parameters.include?(:filter) && @parameters[:filter].present? ? @parameters[:filter] : {}
      @projection = parse_projection(@parameters)

      # remove key_partial_match key from parameters hash
      parameters_for_generic = @parameters.dup
      parameters_for_generic.delete(key_partial_match) if parameters_for_generic.include?(key_partial_match)

      # ensure filter is a hash
      @supplied_filter, was_normalized = normalize_filter_root_array(@supplied_filter)

      # merge filters from qsp partial text match into POST body filter
      partial_match_filters = parse_qsp_partial_match_text(@parameters, key_partial_match, @text_fields)
      @supplied_filter = add_qsp_to_filter(@supplied_filter, partial_match_filters, :or)

      # merge filters from qsp generic equality match into POST body filter
      qsp_generic_filters = parse_qsp(nil, parameters_for_generic, key_prefix)
      @supplied_filter = add_qsp_to_filter(@supplied_filter, qsp_generic_filters, :and)

      # merge default filter into the rest of the filter
      reraise_as_internal_error do
        @filter = merge_filters(@supplied_filter.dup, @default_filter, was_normalized:)
      end

      # populate properties with qsp filter spec
      @qsp_text_filter = @parameters[key_partial_match]
      @qsp_generic_filters = {}
      qsp_generic_filters.each do |key, value|
        @qsp_generic_filters[key] = value[:eq]
      end

      @paging = parse_paging(@parameters, @default_page, @default_items, @max_items)
      @sorting = parse_sorting(@parameters, @default_sort_order, @default_sort_direction)
      @normalized_sorts = normalize_sorting_params(@table, Array(@sorting[:order_by]), @sorting[:direction])
    end

    def query_base
      query = @initial_query.dup

      query_with_archived_if_appropriate(query)
    end

    # Get the query represented by the parameters sent in new.
    # @return [ActiveRecord::Relation] query
    def query_full
      query = query_base

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
      query = query_base

      # restrict to select columns
      query = query_projection(query)

      #filter
      query_filter(query)
    end

    # Get the query represented by the parameters sent in new. DOES NOT include advanced filtering, paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_filter_paging_sorting
      query = query_base

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
      @projected_fields = flatten_projection_hash(@projection)

      # to reliably (and efficiently) sort, calculated fields need to
      # be included in the projection (they're not necessarily returned
      # in the final payload because we still subset the fields
      # when rendering the payload)
      fields_to_project = @projected_fields + @normalized_sorts.filter { _1[:project] }.pluck(:column_name)

      apply_projections(query, @build.projections(fields_to_project))
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_sort(query)
      return query unless has_sort_params?

      apply_sort(query, @normalized_sorts)
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
      @paging[:page].present? && @paging[:items].present?
    end

    def is_paging_disabled?
      ['true', true].include?(@paging[:disable_paging])
    end

    def has_sort_params?
      @sorting[:order_by].present? && @sorting[:direction].present?
    end

    def has_projection_params?
      @projection.present?
    end

    def has_filter_params?
      @filter.present?
    end

    private

    # rebrand the error to be more specific and generate a better error message
    def reraise_as_internal_error
      yield
    rescue CustomErrors::FilterArgumentError => e
      # TODO: this is a bit of a hack, we should split the params validators out
      # from the settings validators rather than doing dodgy error wrapping
      # and re-raising
      error = CustomErrors::FilterSettingsError.new(e.message)
      error.set_backtrace(e.backtrace)
      raise error
    end

    def decode_payload(parameters)
      return parameters unless parameters.include?(:filter_encoded)

      parameters.extract!(:filter_encoded) => { filter_encoded: value }

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

    # normalize a root filter array - the root array syntax is just syntactic sugar
    # for a keyed "and" filter, so we convert it to that
    # @param [Hash,Array] filter
    # @return [Array(Hash,Boolean)]
    def normalize_filter_root_array(filter)
      return [{ and: filter }, true] if filter.is_a?(Array)

      [filter, false]
    end

    # Add qsp spec to filter
    # @param [Hash,Array] filter
    # @param [Hash] additional
    # @param [Symbol] combiner
    # @return [Hash,Array]
    def add_qsp_to_filter(filter, additional, combiner)
      raise 'Additional filter items must be a hash.' unless additional.is_a?(Hash)
      raise 'Filter must be a hash.' unless filter.is_a?(Hash)
      raise 'Combiner should not be blank.' if combiner.blank? || !combiner.is_a?(Symbol)

      # don't do anything unless we need to
      #return filter if additional.size.zero?

      # return a merge of existing filter and qsp filters
      # {
      #   combiner => [
      #     filter,
      #     additional
      #   ]
      # }

      more_than_one = additional.size > 1
      combiner_present = filter.include?(combiner)
      item_without_combiner_exists = filter.keys.any? { |k| [:and, :or, :not].exclude?(k) }

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

    # Merge default filter into supplied filter.
    # @param [Hash,Array] filter
    # @param [Hash,Proc,nil] default
    # @param [Boolean] was_normalized
    #   true if the filter was normalized from a root array
    # @return [Hash,Array]
    def merge_filters(filter, default, was_normalized:)
      return filter if default.blank?

      # @type [Hash]
      default = default.call if default.is_a?(Proc)

      return filter if default.nil? || default.try(:empty?)

      validate_hash(default)

      # convert default filter to an array, if supplied filter is also an array
      if was_normalized
        default = default.map { |key, value| { key => value } }
        # @type [Array]
        merged = default + filter[:and]

        # remove any entries if there are knockouts
        merged.each_with_index do |rule, i|
          # we're not up to the stage where supplied filters have been validated yet
          next unless rule.is_a?(Hash)

          # is any value in the rule a knockout (nil)?
          rule.each do |key, value|
            next unless value.nil?

            # remove the knockout sigil
            rule.delete(key)

            # and search back for the given key in previous entries
            # to do the actual knockout
            merged[0..i].reverse_each do |previous|
              previous.delete(key) if previous.is_a?(Hash) && previous.include?(key)
            end
          end
        end

        # finally remove any empty entries
        merged.reject! do |rule|
          rule.is_a?(Hash) && rule.empty?
        end

        filter.merge(and: merged)
      else
        # merge default filter into filter
        default.deep_merge(filter).compact
      end
    end

    # Add conditions to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Build::Condition>] conditions
    # @return [ActiveRecord::Relation] the modified query
    def apply_conditions(query, conditions)
      conditions.reduce(query) do |query, condition|
        raise 'not a condition' unless condition.is_a?(Models::Condition)

        condition => { predicate:, transforms:, joins: }

        query = apply_transforms(query, transforms) if transforms.present?
        query = apply_joins(query, joins) if joins.present?

        apply_condition(query, predicate)
      end
    end

    # Add condition to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Arel::Nodes::Node] condition
    # @return [ActiveRecord::Relation] the modified query
    def apply_condition(query, condition)
      validate_query_or_select_manager(query)
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
      joins.reduce(query) do |query, join|
        apply_join(query, join)
      end
    end

    # Add join to a query.
    # @param [ActiveRecord::Relation] query
    # @param [String] join
    # @return [ActiveRecord::Relation] the modified query
    def apply_join(query, join)
      validate_query_or_select_manager(query)
      query.joins(join)
    end

    # Append sorting to a query.
    # @param query [ActiveRecord::Relation]
    # @param normalized_sorts [Array<Hash>]
    # @return [ActiveRecord::Relation] the modified query
    def apply_sort(query, normalized_sorts)
      normalized_sorts.reduce(query) do |q, sort|
        raise 'bad sorting hash ' unless sort in { column_name: _, expression:, project: _, direction: }

        if direction == :desc
          Arel::Nodes::Descending.new(expression)
        else
          #direction == :asc
          Arel::Nodes::Ascending.new(expression)
        end => sort_field_by

        q.order(sort_field_by)
      end
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

    # NOTE: only works on one table at a time, which means we don't generate
    # nice available sorting fields for associations on error
    def allowed_sort_fields(valid_fields = @valid_fields, custom_fields2 = @custom_fields2)
      valid_fields + custom_fields2.keys
    end

    # Checks sort fields.
    # Turns the
    def normalize_sorting_params(table, sort_names, default_direction)
      sort_names.map do |sort_name|
        # allow sorting by association
        @build.parse_table_field(table, sort_name) => {
          arel_table: sort_table,
          field_name: sort_field,
          filter_settings: sort_filter_settings,
          table_name: sort_table_name
        }
        sort_custom_fields2 = sort_filter_settings[:custom_fields2] || {}

        # allow sorting by custom fields (only calculated fields)
        if Filter::CustomField.custom_field_defined?(sort_field, sort_custom_fields2)
          if Filter::CustomField.custom_field_is_virtual?(sort_field, sort_custom_fields2)
            raise CustomErrors::FilterArgumentError,
              "Custom field `#{sort_field}` is virtual and not supported for sorting"
          end

          # we ensure the sort field is in the projection,
          # so we can use it directly as an unqualified column name
          project = true
          ::Arel::Nodes::UnqualifiedColumn.new(sort_name)
        else
          project = false
          sort_table[sort_field]
        end => expression

        allowed = allowed_sort_fields(sort_filter_settings[:valid_fields], sort_custom_fields2)
        allowed = allowed.map { |f| :"#{sort_table_name}.#{f}" } if sort_table != table

        validate_table(table)
        validate_name(sort_name, allowed)
        validate_sorting(sort_name, allowed, default_direction)

        { column_name: sort_name, expression:, direction: default_direction, project: }
      end
    end
  end
end
