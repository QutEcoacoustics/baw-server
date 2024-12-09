# frozen_string_literal: true

module FileSystems
  # A virtual file system layer, that can contain multiple sub-layers
  class Virtual < Layer
    include Api::UrlHelpers

    attr_reader :dirs, :filtered_query, :show_dir, :list_dir

    def initialize(*dirs)
      super()

      raise ArgumentError, 'Must provide at least one layer' if dirs.empty?
      unless dirs.all? { |dir| dir.is_a?(Virtual::Directory) }
        raise ArgumentError, 'All layers must be a Virtual::Directory'
      end

      @dirs = dirs
    end

    # @param sub_segments [Array<Segment>] the segments to consume
    def consume_segments(sub_segments, data)
      # for each segment consume a virtual directory

      # the base query needs to be augmented with filter conditions for each
      # segment we consume. e.g. if we have a projects virtual directory then
      # we need to filter by the project id that is provided in the path.
      base_query = data[:root].base_query

      consumed = 0
      conditions = nil
      dirs.each_with_index do |dir, index|
        segment = sub_segments.at(index)
        # not enough segments to keep going
        break if segment.nil?

        # if we hit special tokens :children or :grandchildren then we don't
        # want to add filter conditions (because we only filter up to parent
        # which is the end of the requested path)
        if segment.children?
          @list_dir = dir
        elsif segment.grandchildren?
          # noop
        else
          # add filter for normal segments
          condition = dir.filter_condition(segment)
          conditions = conditions.nil? ? condition : conditions.and(condition)

          base_query = dir.add_joins(base_query)
          @show_dir = dir
        end

        consumed += 1
      end

      base_query = base_query.where(conditions) if consumed.positive?

      # base query can either be used as a base for filtering.
      # if we're listing children a projection is placed on top
      @filtered_query = base_query

      consumed
    end

    def show(data)
      # @type [Virtual::Directory]
      dir = show_dir

      data => {root:, segments:}

      is_deepest_dir = dirs.last == dir || dir.include_base_ids
      query = dir.entries(filtered_query, 0, 1, include_base_ids: is_deepest_dir)

      # execute the query! select_all extracts bind values (unlike exec_query)
      item = dir.model.connection.select_all(
        query,
        "List virtual directory for #{dir.model.name}"
      )

      return nil if item.count.zero?

      item.cast_values.first => [total, id, base_ids, *names_and_paths]

      # choose whichever name and path matches our route parameter
      if dir.alternates.length > 1
        names_and_paths.find_index { |path_or_name| path_or_name.to_s == segments.last.to_s }
      else
        # interleaved names and paths, so the first path is index 1
        1
      end => path_index

      FileSystems::Structs::DirectoryWrapper.new(
        path: root.make_path(*segments),
        # interleaved names and paths, so the name for the path index is index - 1
        name: names_and_paths[path_index - 1]&.to_s,
        # can't answer that here
        #has_children:,
        link: dir.make_link(url_helpers, id),
        virtual_item_ids: base_ids || [],
        data: root.additional_data(base_ids)
      )
    end

    def list(data)
      # @type [Directory]
      dir = list_dir

      data => {root:, segments:, paging: { offset:, limit: }}

      is_deepest_dir = dirs.last == dir || dir.include_base_ids
      query = dir.entries(filtered_query, offset, limit, include_base_ids: is_deepest_dir)

      # execute the query! select_all extracts bind values (unlike exec_query)

      children = dir.model.connection.select_all(
        query,
        "List virtual directory for #{dir.model.name}"
      )

      total = nil
      results = children.cast_values.map { |query_total, id, base_ids, *names_and_paths|
        total ||= query_total
        # If more than one name / path combination exists then we return them all
        # but we keep them grouped into one entry since they represent one item
        # and this won't affect paging.
        # We use unwrap to just return scalar values in the most common case.
        names, paths = names_and_paths.deinterlace { |name, path| name.present? && path.present? }
        FileSystems::Structs::Directory.new(
          path: paths.map { |path| root.make_path(*segments, path.to_s) }.unwrap,
          name: names&.map(&:to_s)&.unwrap,
          # See `#have_children` for why this is `true`
          has_children: true,
          link: dir.make_link(url_helpers, id),
          virtual_item_ids: base_ids || []
        )
      }

      [results, total]
    end

    def have_children(children, _data)
      # Because the virtual directories are a virtual hierarchy generated from a
      # base query, they either
      # 1. exist and thus necessarily have children all the way down to the
      #   base entity that generated it
      # 2. don't exist and thus don't have children - so we're not asking this
      #   question anyway.
      #
      # For the edge cases:
      # - first directory: because root is the first layer, virtual is the child,
      #   and thus virtual can never be a grandchild at fist directory
      # - last directory: that question is answered by have_children in the
      #   physical layer.
      #
      # TL;DR: noop.
      children
    end

    def filtered_query_results
      @filtered_query_results ||= filtered_query.to_a
    end
  end
end
