# frozen_string_literal: true

module FileSystems
  # represents the physical file system
  # one or more directories that have been filtered by the virtual layer
  class Physical < Layer
    # A list of paths that exist on the file system
    # @return [Hash<Integer,Pathname>]
    attr_reader :paths

    # Whether to show hidden files
    # @return [Boolean]
    attr_reader :show_hidden

    # @param items_to_paths [Proc] a proc that takes an array of items and returns
    #   an array of Pathname objects
    # @param show_hidden [Boolean] whether to show hidden files
    def initialize(items_to_paths:, show_hidden: false)
      super()
      raise ArgumentError, 'items_to_paths must be a proc' unless items_to_paths.is_a?(Proc)

      @items_to_paths = items_to_paths
      @show_hidden = show_hidden

      @paths = {}
    end

    # @param sub_segments [Array<Segment>] the segments that are being consumed
    def consume_segments(sub_segments, data)
      # if we're at this point we require the virtual layer to have consumed
      # all segments up to the physical layer and we need the virtual layer's query to be
      # executed
      items = data[:virtual].filtered_query_results

      # convert the items into a list of paths that exist on the file system
      items_and_paths = convert_items_to_paths(items)

      # for each segment consume a physical directory
      consumed = 0

      stop_consumption = false
      sub_segments.each do |segment|
        # not enough segments to keep going
        break if segment.nil?

        # we have two types of segments:
        # - string fragments that represent a file entry
        # - special segments that represent children or grandchildren
        case segment
        when segment.children?
          # what does this mean?
          # to be able to list items we need any of our paths to be a directory
          # TODO: or be a container which is essentially a virtual directory
          break unless items_and_paths.all? { |_item, path| path_empty?(path) }
        when segment.grandchildren?
          # similarly to children, if there are any directories that exist
          # then we can list grandchildren
          break unless items_and_paths.any? { |_item, path|
                         path_type(path, data) == :dir
                       }
        else
          # otherwise build up the path like normal by "filtering" base paths
          # with segments
          filtered = items_and_paths.filter_map { |item, path|
            child = path / segment

            # if the constructed path does exist and is a container file,
            # then we can consume it if the mime type matches the accept header
            type = path_type(child, data)

            # doesn't exist
            next nil unless type

            # if type is dir_file then we've found a file that is a container
            # the physical layer renders the directory wrapper, but the container
            # layer will render the children.
            # We need to stop scanning any deeper.
            stop_consumption = true if type == :dir_file

            [item, child]
          }

          # not enough paths to keep going.
          # don't overwrite the paths if we have no results - we want to keep
          # the most deep existing path
          break if filtered.empty?

          # replace with paths that are built up with the current segment
          items_and_paths = filtered
        end

        consumed += 1
        break if stop_consumption
      end

      # store a map of segment to paths so that we can use it later
      # hash of item id as the key and the path as the value
      @paths = items_and_paths.to_h { |item, path| [item.id, path] }

      # we can inject extra data now because we are showing the current resource
      data[:additional_data].merge!(data[:root].additional_data(items)) if consumed.positive?

      consumed
    end

    def show(data)
      # we can have multiple paths if two virtual items match the criteria
      # e.g. there are two recordings filtered by the same date, and there are
      # results for each recording.
      # if we are showing as we enter the physical file system, then the directory
      # then it means that both result directories have an identical path within
      # each... (otherwise consume_segments would have filtered out one or the other)

      # should never happen
      paths_only = paths.values
      raise "paths are not identical: #{paths_only.inspect}" unless paths_only.map(&:to_s).uniq.count == 1

      path = paths_only.first

      return nil unless path.exist?

      data => { root:, segments:, virtual: }

      route = root.make_path(segments)
      name = path.basename.to_s

      if path_type(path, data) == :file
        path.extname[1..]
        Structs::FileWrapper.new(
          path: route,
          name:,
          size: path.size,
          mime: mime_type(path),
          io: path.open,
          data: root.additional_data(virtual.filtered_query),
          virtual_item_ids: virtual.filtered_query_results.map(&:id),
          physical_paths: [path],
          modified: path.mtime
        )
      else
        Structs::DirectoryWrapper.new(
          path: route,
          name:,
          # `link` is nil here: we don't need to cross link to another resource
          # because be definition we are showing file system results for the
          # current resource
          data: root.additional_data(virtual.filtered_query),
          virtual_item_ids: virtual.filtered_query_results.map(&:id),
          physical_paths: [path]
        )
      end
    end

    def list(data)
      # NOTE: added a sort here for stable sorting. We're pivoting away from
      # having thousands of files in folders so hopefully we can take penalty
      # hit of evaluating the entire directory listing each time
      all_children = paths
        .values
        .uniq
        .flat_map(&:children)

      # exclude hidden files

      all_children.reject!(&:hidden?) unless show_hidden
      all_children.sort_by!(&:basename)

      # assert we're working with an array. TODO: remove
      raise unless all_children.is_a?(Array)

      total = all_children.count

      # now subset for paging and transform into our structs
      data => { paging: { limit: limit, offset: offset } }
      children = all_children
        .drop(offset)
        .if_then(limit) { |x| x.take(limit) }
        .map { |path|
        make_child(path, data)
      }

      [children, total]
    end

    def have_children(children, _data)
      #paths.join(*_matched_segments.last)
      children.map { |child|
        if child.physical_paths.empty?
          # use metadata on child to pull out the path
          # this is only needed when the current layer is a grandchild - i.e.
          # the all layers previously have not been physical
          paths.values_at(*child.virtual_item_ids).uniq
        else
          # list and show will have already set the physical paths
          child.physical_paths
        end => child_paths

        # we're always passed directories here
        # We need to know if it's empty or not
        non_empty = child_paths.any? { |path| !path_empty?(path) }

        # no need to modify the object, has_children defaults to false
        next child unless non_empty

        child.new(has_children: true)
      }
    end

    def mime_type(path)
      extension = path.extname[1..]

      result = Mime::Type.lookup_by_extension(extension)

      return result.to_s if result.present?

      'application/octet-stream'
    end

    private

    # Determine if a directory is empty
    # @param path [Pathname]
    # @return [Boolean]
    def path_empty?(path)
      return true if path.nil?

      path.empty?
    end

    # Determine if the path is a directory or a file, including support for
    # container files.
    # @param path [Pathname]
    # @return [Symbol,nil] :dir, :file, :dir_file or nil if the file does not exist.
    #   Will also return nil if the path is hidden.
    def path_type(path, data)
      return nil unless path.exist?
      return nil if path.hidden? && !show_hidden

      return :dir if path.directory?

      data => { accept:, container: container_layer }

      return :file unless container_layer

      container_layer.container_as_file?(path, accept) ? :file : :dir_file
    end

    # Convert the items into a list of paths that on the file system.
    # The paths pay not yet exist yet.
    # @param items [Array<ActiveRecord::Base>]
    # @return [Array<Array(::ActiveRecord::Relation,Pathname)>]
    def convert_items_to_paths(items)
      items.zip(@items_to_paths.call(items))
    end

    def make_child(path, data)
      data => { root:, segments:, virtual: }

      name = path.basename.to_s

      # we need to know if the path is a directory or a file
      # if it's a directory then we need to know if it's empty or not
      # if it's a file then we need to know the size and mime type
      type = path_type(path, data)

      route = root.make_path(*segments, path.basename.to_s)

      # if it's a file then we need to know the size and mime type
      common = {
        path: route,
        name:,
        virtual_item_ids: virtual.filtered_query_results.map(&:id),
        physical_paths: [path]
      }

      case type
      when :file
        Structs::File.new(
          **common,
          size: path.size,
          mime: mime_type(path)
        )
      when :dir
        Structs::Directory.new(
          **common
          # `link` is nil here: we don't need to cross link to another resource
          # because be definition we are showing file system results for the
          # current resource
        )
      when :dir_file
        Structs::DirectoryFile.new(
          **common,
          size: path.size,
          mime: mime_type(path)
        )
      end
    end
  end
end
