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
                :qsp_generic_filters, :paging, :sorting

    # Convert a json POST body to an arel query.
    # @param [Hash] parameters
    # @param [ActiveRecord::Relation] query
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    def initialize(parameters, query, model, filter_settings)
      # might need this at some point: Rack::Utils.parse_nested_query
      @key_prefix = 'filter_'
      @default_page = 1
      @default_items = 25
      @max_items = 500
      @table = relation_table(model)

      # `.all' adds 'id' to the select!!
      @initial_query = !query.nil? && query.is_a?(ActiveRecord::Relation) ? query : relation_all(model)
      @valid_fields = filter_settings[:valid_fields].map(&:to_sym)
      @text_fields = filter_settings[:text_fields].map(&:to_sym)
      @render_fields = filter_settings[:render_fields].map(&:to_sym)
      @filter_settings = filter_settings

      @build = Build.new(@table, filter_settings)

      @parameters = CleanParams.perform(parameters)
      validate_hash(@parameters)

      @filter = @parameters[:filter]
      @filter = {} if @filter.blank?

      @projection = @parameters[:projection]
      @projection = nil if @projection.blank?

      @qsp_text_filter = parse_qsp_text(@parameters)




      @qsp_generic_filters = parse_qsp(nil, @parameters, @key_prefix, @valid_fields)
      @paging = parse_paging(
          @parameters,
          @default_page,
          @default_items,
          @max_items)
      @sorting = parse_sorting(
          @parameters,
          filter_settings[:defaults][:order_by],
          filter_settings[:defaults][:direction])
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

      # add qsp text filters
      query = query_filter_text(query)

      # add qsp generic_filters
      query = query_filter_generic(query)

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

      # add qsp text filters
      query = query_filter_text(query)

      # add qsp generic_filters
      query = query_filter_generic(query)

      # result
      query
    end

    # Get the query represented by the parameters sent in new. DOES NOT include advanced filtering, paging or sorting.
    # @return [ActiveRecord::Relation] query
    def query_without_filter_paging_sorting
      query = @initial_query.dup

      # restrict to select columns
      query = query_projection(query)

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
    def query_filter(query)
      if has_filter_params?
        conditions, joins = @build.parse(@filter)

        # add distinct if there are joins
        query = query.distinct if joins.size > 0

        query = apply_conditions(query, conditions)
        query = apply_joins(query, joins) if joins.size > 0
        query
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

    # Add text filter to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_filter_text(query)
      return query unless has_qsp_text?
      # only text fields on the /filter model can be used - can't filter on other table fields
      text_condition = @build.contains_text(@qsp_text_filter)
      apply_condition(query, text_condition)
    end

    # Add text filter to a query.
    # @param [ActiveRecord::Relation] query
    # @param [String] filter_text
    # @return [ActiveRecord::Relation] query
    def query_filter_text_custom(query, filter_text)
      # only text fields on the /filter model can be used - can't filter on other table fields
      text_condition = @build.contains_text(filter_text)
      apply_condition(query, text_condition)
    end

    # Add generic equality filters to a query.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_filter_generic(query)
      return query unless has_qsp_generic?
      # only fields on the /filter model can be used - can't filter on other table fields
      apply_condition(query, @build.generic_equals(@qsp_generic_filters))
    end

    # Add generic equality filters to a query.
    # @param [ActiveRecord::Relation] query
    # @param [Hash] filter_hash
    # @return [ActiveRecord::Relation] query
    def query_filter_generic_custom(query, filter_hash)
      # only fields on the /filter model can be used - can't filter on other table fields
      apply_condition(query, @build.generic_equals(filter_hash))
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

    def has_qsp_generic?
      !@qsp_generic_filters.blank?
    end

    def has_qsp_text?
      !@qsp_text_filter.blank?
    end

    private

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

      if direction == :asc
        query.order(table[column_name].asc)
      elsif direction == :desc
        query.order(table[column_name].desc)
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