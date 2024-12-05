# frozen_string_literal: true

module FileSystems
  class Virtual
    # One sub-layer of a virtual file system directory hierarchy
    class Directory
      # @return [ActiveRecord::Base]
      attr_reader :model

      # @return [Array<Virtual::NamePath>]
      attr_reader :alternates

      # @return [Symbol,Hash,nil]
      attr_reader :base_query_joins

      # @return [Boolean]
      attr_reader :include_base_ids

      # A virtual directory that represents a model.
      # It maps a series of ids from route parameters to a model and returns
      # pairs of names and IDs to use as directory entries.
      # @param alternates [Array<Symbol,AlternateNamePath,::Arel::Nodes::Node>] An array of tuples that represent
      #   alternate names or paths for this directory.
      #   Providing `nil` or an empty array will
      #   result in a default ID based name/path being used, which is the primary
      #   key of the model.
      #   Providing a symbol or Arel node will result in the column with that name being used and
      #   the path defaulting to `Model[:id]`.
      #   Multiple path expressions can be provided to allow for multiple
      #   alternative paths to the same model.
      # @param base_query_joins [Hash,nil] the joins to add to the base query in the
      #   active record hash format
      # @param include_base_ids [Boolean] whether to include the base ids in the
      #   result set. Base ids will be returned as an array of integers that
      #   represent the ids of the base items that the virtual items are linked to.
      #   Should only be true on the last layer (or a sufficiently restricted layer)
      #   or else an array of thousands of
      #   ids will be returned for each virtual item.
      # @example uses the default path and name of `id`
      #  Virtual::Directory.new(AudioRecording)
      # @example  uses the default path of `id` and the name of `name`
      #  Virtual::Directory.new(Site, [:name])
      # @example Provides for two alternate paths to the same model
      #  # - one using the analysis identifier as the path and the name
      #  # - one using the name as the name and the id as the path
      #  Virtual::Directory.new(
      #    Script,
      #    [
      #      AlternateNamePath.new(Script.arel_table[:analysis_identifier], TO_S, Script.arel_table[:analysis_identifier]),
      #      AlternateNamePath.new(Script.arel_table[:name], TO_INT)
      #    ]
      def initialize(model, alternates = nil, base_query_joins: nil, include_base_ids: false)
        raise ArgumentError, 'Model must be an ActiveRecord::Base' unless model < ActiveRecord::Base

        alternates = Array(alternates)
        alternates = [:id] if alternates.empty?
        alternates = alternates.map { |alt| Virtual::NamePath.normalize(model, alt) }

        unless base_query_joins.nil? || base_query_joins.is_a?(Hash) || base_query_joins.is_a?(Symbol)
          raise ArgumentError, 'base_query_joins must be a hash or a symbol'
        end

        raise ArgumentError, 'include_base_ids must be a boolean' unless [true, false].include?(include_base_ids)

        @model = model
        @alternates = alternates
        @base_query_joins = base_query_joins
        @include_base_ids = include_base_ids
      end

      # @param param [Segment] the router parameter to filter by
      # @return [Arel::Nodes::Node]
      def filter_condition(param)
        value = param.to_s

        # build up a list of possible expressions on which to match a row
        # to the route parameter
        @alternates.reduce(nil) do |condition, name_path|
          normalized = name_path.coerce.call(value)

          if normalized.nil?
            # if normalized is nil, we can't match on this path
            nil
          else
            # anti sql injection
            bind_param = Arel::Nodes::BindParam.new(normalized)
            name_path.condition.call(bind_param)
          end => expression

          condition.nil? ? expression : condition.or(expression)
        end
      end

      def add_joins(base_query)
        return base_query if @base_query_joins.nil?

        base_query.joins(@base_query_joins)
      end

      # @param conditions [ActiveRecord::Relation] the base query to filter by
      # @param skip [Integer]
      # @param take [Integer, nil]
      # @param include_base_ids [Boolean] whether to include the base ids in the
      #   result set. Base ids will be returned as an array of integers that
      #   represent the ids of the base items that the virtual items are linked to.
      #   Should only be true on the last layer or else an array of thousands of
      #   ids will be returned for each virtual item.
      # @return [Arel::SelectManager]
      def entries(conditions, skip, take, include_base_ids: false)
        # implementors note:
        # we separate the grouping out into it's own CTE
        # so we can execute the query in steps.
        # In the outer query we have to support arbitrary expressions. If we had
        # grouped there, every field reference would need to be done through
        # an aggregate function which would require us to ??rewrite supplied AST??.
        # So three stages:
        # 1. inner query to do joins and condition filtering
        # 2. outer query to do expression generation of names and paths
        # 3. grouping query to group by the first name
        #      - and this last step does paging and total count

        table = model.arel_table

        inner_table = Arel::Table.new('inner_table')
        inner_query = add_joins(conditions)
          .select(
            table[:id].as('id'),
            (include_base_ids ? conditions.model.arel_table[:id] : Arel.null).as('base_ids')
          )
          # returns the select manager
          .arel
          # ast returns the arel ast with bind values still in place
          .ast

        outer_table = Arel::Table.new('outer_table')

        name0 = outer_table['name_0']

        name_and_path_expressions, name_and_path_aliases = make_name_path_projections

        projection = [
          # the id of the virtual item - used for making links.
          # `path` is commonly just the id, but when it isn't we need the id as well.
          inner_table[:id].as('id'),
          # allow us to link back to the base item - this can be used in other layers
          inner_table['base_ids'],
          *name_and_path_expressions
        ]

        # the main query
        outer_query = model
          .arel_table
          .join(inner_table.grouping(inner_query).as(inner_table.name))
          .on(table[:id].eq(inner_table[:id]))
          .project(*projection)

        # the grouping query
        # allows us to arbitrary projections on the name and path
        # and then afterwards aggregate the columns
        grouping_table = Arel::Table.new('grouping_table')
        grouping_query = outer_table
          .project(
            # We also only want to return the id if uniquely resolves to 1 items.
            outer_table['id'].count(true).eq(1).when(Arel.true).then(outer_table['id'].maximum).else(nil).as('id'),
            (include_base_ids ? outer_table['base_ids'].array_agg : Arel.null).as('base_ids'),
            *name_and_path_aliases.map { |name_or_path| outer_table[name_or_path].maximum.as(name_or_path) }
          )
          .group(name0)

        # using the CTE allows us to get the total count of results without
        # having to run the query twice. It was possible to do this without a
        # CTE but it counted non-distinct results which returned a incorrect
        # total count.
        grouping_table
          .project(
            # get a count of all results, ignoring the limit and offset, for paging
            # https://stackoverflow.com/a/28888696/224512
            Arel.star.count.over.as('total'),
            Arel.star
          )
          .order(name0.unqualified.asc)
          .skip(skip)
          .if_then(take) { |query| query.take(take) }
          .with(
            Arel::Nodes::As.new(outer_table, outer_query),
            Arel::Nodes::As.new(grouping_table, grouping_query)
          )
      end

      def make_name_path_projections
        # in the scenario where we have alternate names/paths that could match,
        # so return all as extra columns. We'll choose the correct one later.
        # Bundling them in extra columns allows us to not affect paging calculations.
        # NOTE: we tried using arrays but it messed with the distinct on clause.
        size = 2
        names_and_paths = Array.new(alternates.length * size)
        outer_names_and_paths = Array.new(alternates.length * size)

        alternates.each_with_index do |alternate, index|
          # .as mutates the node, which means when name and path are the same
          # it can double alias it which is an error. The grouping wraps it in a
          # new node
          name = Arel.grouping(alternate.name).as("name_#{index}")

          path = Arel.grouping(alternate.path).as("path_#{index}")

          offset = index * size
          names_and_paths[offset, size] = [name, path]

          outer_names_and_paths[offset, size] = ["name_#{index}", "path_#{index}"]
        end

        [names_and_paths, outer_names_and_paths]
      end

      def make_link(url_helpers, id)
        # if more than one item is represented by this entity, do not form a link to it
        return nil unless id.is_a?(Integer)

        # make a link to the virtual resource we're referring to
        url_helpers.url_for(
          controller: model.name.underscore.pluralize,
          action: :show,
          id:,
          only_path: true
        )
      end
    end
  end
end
