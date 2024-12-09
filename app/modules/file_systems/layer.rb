# frozen_string_literal: true

module FileSystems
  class Layer
    # @return [Integer] the number of segments from the start of sub_segments
    #   that were consumed
    def consume_segments(_sub_segments, _data)
      raise NotImplementedError
    end

    # return an object representing the current layer
    # @param segments [Array<String>] the segments for this current layer
    # @param data [Hash] the data for this request
    # @return [FileSystems::Structs::DirectoryWrapper, FileSystems::Structs::FileWrapper]
    def show(data)
      raise NotImplementedError
    end

    # list is called when
    # the target layer is the parent of this one
    # and so now we have to list the children
    # @param data [Hash] the data for this request
    # @return [Array(Array<FileSystems::Structs::Directory, FileSystems::Structs::File, FileSystems::Structs::DirectoryFile>,Integer)]
    def list(data)
      raise NotImplementedError
    end

    # called when we have a page of children
    # and we need to find out if they have any
    # children of their own
    # (get information about grandchildren)
    # @param children [Array<FileSystems::Structs::Directory, FileSystems::Structs::DirectoryFile>] the children to check
    # @param data [Hash] the data for this request
    # @return [Array<FileSystems::Structs::Directory, FileSystems::Structs::DirectoryFile>]
    def have_children(children, data)
      raise NotImplementedError
    end
  end
end
