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
                :qsp_generic_filters, :paging, :sorting, :build

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

      validate_filter_settings(filter_settings)
      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @text_fields = filter_settings.include?(:text_fields) ? filter_settings[:text_fields].map(&:to_sym) : []
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      @filter_settings = filter_settings
      @default_sort_order = filter_settings[:defaults][:order_by]
      @default_sort_direction = filter_settings[:defaults][:direction]

      @build = Build.new(@table, filter_settings)

      @parameters = CleanParams.perform(parameters)
      validate_hash(@parameters)

      @filter = @parameters.include?(:filter) && !@parameters[:filter].blank? ? @parameters[:filter] : {}
      @projection = @parameters.include?(:projection) && !@parameters[:projection].blank? ? @parameters[:projection] : nil

      # remove key_partial_match key from parameters hash
      parameters_for_generic = @parameters.dup
      parameters_for_generic.delete(key_partial_match) if parameters_for_generic.include?(key_partial_match)

      # merge filters from qsp partial text match into POST body filter
      partial_match_filters = parse_qsp_partial_match_text(@parameters, key_partial_match, @text_fields)
      add_qsp_to_filter(@filter, partial_match_filters, :or)

      # merge filters from qsp generic equality match into POST body filter
      qsp_generic_filters = parse_qsp(nil, parameters_for_generic, key_prefix)
      add_qsp_to_filter(@filter, qsp_generic_filters, :and)

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
      query = query_paging(query)

      # result
      query
    end

    # Get the query represented by the parameters sent in new. DOES NOT include paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_paging_sorting
      query = @initial_query.dup

      # restrict to select columns
      query = query_projection(query)

      #filter
      query = query_filter(query)

      # result
      query
    end

    # Get the query represented by the parameters sent in new. DOES NOT include advanced filtering, paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_filter_paging_sorting
      query = @initial_query.dup

      # restrict to select columns
      query = query_projection(query)

      # result
      query
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

    # Add projections to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Symbol>] filter_projection
    # @return [ActiveRecord::Relation] query
    def query_projection_custom(query, filter_projection)
      apply_projections(query, @build.projections({include: filter_projection}))
    end

    # Add default projections to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_projection_default(query)
      apply_projections(query, @build.projections({include: @render_fields}))
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_sort(query)
      return query unless has_sort_params?
      apply_sort(query, @table, @sorting[:order_by], @valid_fields, @sorting[:direction])
    end

    # Add sorting to query.
    # @param [ActiveRecord::Relation] query
    # @param [Symbol, String] order_by
    # @param [Symbol, String] direction
    # @return [ActiveRecord::Relation] query
    def query_sort_custom(query, order_by, direction)
      apply_sort(query, @table, order_by, @valid_fields, direction)
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
    # @param [ActiveRecord::Relation] query
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


    # Add qsp spec to filter
    # @param [Hash] filter
    # @param [Hash] additional
    # @param [Symbol] combiner
    # @return [void]
    def add_qsp_to_filter(filter, additional, combiner)
      fail 'Additional filter items must be a hash.' unless additional.is_a?(Hash)
      fail 'Filter must be a hash.' unless filter.is_a?(Hash)
      fail 'Combiner be blank.' if combiner.blank? || !combiner.is_a?(Symbol)

      more_than_one = additional.size > 1
      combiner_present = filter.include?(combiner)
      item_without_combiner_exists = filter.keys.any?{ |k| ![:and, :or, :not].include?(k)}

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
            fail 'Problem adding additional filter items.'
          end
        end
    end

    # Add conditions to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Array<Arel::Nodes::Node>] conditions
    # @return [ActiveRecord::Relation] the modified query
    def apply_conditions(query, conditions)
      conditions.each do |condition|
        query = apply_condition(query, condition)
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
      sort_field = @build.build_custom_field(column_name)
      sort_field = table[column_name] if sort_field.blank?

      if sort_field.is_a? String
        sort_field_by = sort_field
      else

        if direction == :desc
          sort_field_by = Arel::Nodes::Descending.new(sort_field)
        else
          #direction == :asc
          sort_field_by = Arel::Nodes::Ascending.new(sort_field)
        end

      end

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
      query.select(projection)
    end

  end
end