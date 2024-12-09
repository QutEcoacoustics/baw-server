# frozen_string_literal: true

module FileSystems
  class Container < Layer
    attr_reader :containers, :current_container

    def initialize
      super()

      # fixed implementation for now to manage complexity
      @containers = [
        FileSystems::Containers::Zip.new,
        FileSystems::Containers::Sqlite.new
      ]
    end

    def consume_segments(sub_segments, data)
      # the segments should always refer to things in the container, not to the
      # file that is the container itself.
      physical_layer = data[:physical]

      # we still need a uniq because two items can point to the same path
      paths = physical_layer.paths.values.uniq
      unless paths.count == 1
        raise ArgumentError,
          'Must have exactly one path by the time we get to the container'
      end

      container_path = paths.first

      # we need to find the first container that can consume the segments
      # and then call consume_segments on that container
      @current_container = @containers.find { |c| c.container_extension?(container_path) }

      # if we can't find a container then we can't consume the segments,
      # This should never happen though because we aren't here unless we have
      # already passed the container_extension? check in the physical layer
      raise "No container supports extension#{container_path.extension}" unless current_container

      current_container.container_path = container_path

      # no consume as normal in the correct container layer
      current_container.consume_segments(sub_segments, data)
    end

    delegate :show, to: :current_container

    delegate :list, to: :current_container

    delegate :have_children, to: :current_container

    def container_extension?(path)
      @containers.any? { |container| container.container_extension?(path) }
    end

    def container_as_file?(path, accept)
      found = @containers.find { |container| container.container_extension?(path) }

      return true unless found

      found.mime_type == accept
    end

    def self.common_attributes(data, container_path)
      data => { root:, segments:, virtual:}

      {
        data: root.additional_data(virtual.filtered_query),
        virtual_item_ids: virtual.filtered_query_results.map(&:id),
        physical_paths: [container_path]
      }
    end
  end
end
