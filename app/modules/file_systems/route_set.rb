# frozen_string_literal: true

module FileSystems
  # Represents a virtual file system exposed by routes over HTTP.
  # The layers have a fixed order:
  #  1. root
  #  2. virtual (flexible database backed hierarchy)
  #  3. physical (or in future work, remote) (real files on a filesystem)
  #  4. container (files that contain other files, such as sqlite or zip files)
  class RouteSet
    # implementor's note: I originally designed this as a fully flexible layer
    # system that could have any number of layers in any order, with an abstract
    # and generic interface. However,
    # that is way too complex and after several weeks of iterations I have
    # realized that it is not necessary. KISS.
    # A fixed layout handles all our use cases and is much easier to reason about.
    # There is still a lot of flexibility available in the hierarchies of the
    # virtual layer though.

    # the directory delimiter used in the path
    DIRECTORY_DELIMITER = '/'

    # flag any directory traversal
    # flag any control characters or tilde
    # do not allow leading dots representing hidden files
    PATH_SEGMENT_REJECTOR = /^\.\.$|^\.|[~\p{Cntrl}]/

    # Same as `PATH_SEGMENT_REJECTOR` but allows leading dots
    PATH_SEGMENT_REJECTOR_ALLOW_HIDDEN = /^\.\.$|[~\p{Cntrl}]/

    # @return [Root]
    attr_reader :root

    # @return [Virtual]
    attr_reader :virtual

    # @return [Physical]
    attr_reader :physical

    # @return [Container, nil]
    attr_reader :container

    # @return [Array<Layer>]
    attr_reader :layers

    def initialize(root:, virtual:, physical:, container: nil)
      raise ArgumentError, 'root must be a root layer' unless root.is_a?(Root)
      raise ArgumentError, 'virtual must be a virtual layer' unless virtual.is_a?(Virtual)
      raise ArgumentError, 'physical must be a physical layer' unless physical.is_a?(Physical)
      raise ArgumentError, 'container must be a container layer' unless container.nil? || container.is_a?(Container)

      @root = root
      @virtual = virtual
      @physical = physical
      @container = container
      @layers = [root, virtual, physical, container].compact
    end

    # returns either a DirectoryWrapper or a FileWrapper to return to a
    # controller to render directly to the client.
    # @param path [String] the path to the file or directory, relative to the root of the file system
    # @param accept [String] the accept type of the request
    # @param paging [Hash] a hash of paging options (as per Filter API)
    def show(path, accept, paging, **additional_data)
      raise ArgumentError, 'path must be a string' unless path.is_a?(String)

      segments = split_and_validate_path(path)

      data = {
        accept:,
        paging: normalize_paging(paging),
        segments:,
        root:,
        virtual:,
        physical:,
        container:,

        # allow layers to insert things if they want
        additional_data:
      }

      # Consume layers until we have no more segments.
      # We represent children and grandchildren as segments so we can find which
      # layers support those operations in the one pass.
      remaining_segments = Segment.path_list_to_segments(segments)

      target = nil
      children = nil
      grandchildren = nil
      layers.each do |layer|
        # layers are responsible for filtering when consume_segments is called.
        # they can update the data with relevant results
        consumed = layer.consume_segments(remaining_segments, data)

        # nothing matched, so we can't find the requested item
        break if consumed.zero?

        consumed_segments = remaining_segments.take(consumed)
        remaining_segments = remaining_segments.drop(consumed)

        # assign target, children, and grandchildren layers if the current layer
        # consumed those tokens
        target = layer if consumed_segments.any?(&:last?)
        children = layer if consumed_segments.any?(&:children?)
        grandchildren = layer if consumed_segments.any?(&:grandchildren?)

        # don't return a consume result and thus filter out the layer
        break if remaining_segments.empty?
      end

      raise ::CustomErrors::ItemNotFoundError, path if target.nil?

      # so show the target layer
      result = target.show(data)

      raise ::CustomErrors::ItemNotFoundError if result.nil?

      # and then if it is a directory wrapper show the children
      if result.is_a?(FileSystems::Structs::DirectoryWrapper)
        child_entries = []
        # if we've run out of layers there are not more children
        child_entries, total_count = children.list(data) if children

        #  then we ask the final layer if any of the children have children
        if grandchildren
          directories, files = child_entries.partition(&:directory?)
          updated_directories = grandchildren.have_children(directories, data)
          child_entries = updated_directories + files
        end

        # also take this opportunity to merge in any additional data we have
        result = result.new(
          children: child_entries,
          data: result.data.merge(additional_data),
          total_count: total_count || 0
        )
      end

      result
    end

    private

    # @param path [String] the path to the file or directory, relative to the root of the file system
    # @return [Array<Segment>]
    def split_and_validate_path(path)
      raise ArgumentError, 'path must be a string' unless path.is_a?(String)

      # e.g. /1/2/3/abc/def.txt
      # [1, 2, 3, 'abc', 'def.txt']
      path.split(DIRECTORY_DELIMITER).filter { |segment|
        regex = physical.show_hidden ? PATH_SEGMENT_REJECTOR_ALLOW_HIDDEN : PATH_SEGMENT_REJECTOR
        raise CustomErrors::IllegalPathError if segment =~ (regex)

        # keep only non-empty strings
        segment.present?
      }
    end

    def normalize_paging(paging)
      paging = Filter::Query::DEFAULT_PAGING.merge(paging || {})

      if paging[:disable_paging]
        paging[:offset] = 0
        paging[:limit] = nil
      end

      if paging[:limit].nil? || paging[:limit] > Filter::Query::DEFAULT_PAGE_MAX_ITEMS || paging[:limit] < 1
        paging[:limit] = Filter::Query::DEFAULT_PAGE_ITEMS
      end
      paging
    end
  end
end
