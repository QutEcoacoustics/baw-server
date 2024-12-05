# frozen_string_literal: true

require 'zip'
#require 'zip/filesystem'

module FileSystems
  module Containers
    # A container for a zip file.
    class Zip
      # Implementor's note:
      # We did attempt to use zip/filesystem abstraction but it was not
      # rendering directories at all (it appears adding directory entries.
      # into zips is optional and this abstraction does not render missing ones).
      # For our purposes this makes the abstraction useless.
      # Even the glob entries API does not work as expected... it doesn't return
      # simulated directories as entries.
      # So now we build up an index when we open the file 🤦‍♂️

      # We only need to build up an hierarchical index of the zip.
      # We can pull more information from the zip file if we need to.
      # @return [Hash<String, ::Zip::ZipEntry>]
      attr_reader :index

      attr_accessor :container_path

      attr_reader :zip_file, :path_within_container

      MIME = 'application/zip'
      INDEXER_CONFLICT = lambda { |existing, new|
        # we're accounting for a case where we indexed a file before a directory
        existing.is_a?(Hash) ? existing.merge(new) : existing
      }

      def initialize
        @index = {}
      end

      def consume_segments(sub_segments, _data)
        @zip_file = ::Zip::File.open(container_path)
        build_index

        consumed = 0
        path_within_container = []

        sub_segments.each do |segment|
          if segment.children?
            # if the path keys return a hash with any items in it, then we have
            # a directory and can list children
            break unless dig_index(path_within_container).is_a?(Hash)
          elsif segment.grandchildren?
            # if the path keys return a hash (a directory) which itself has
            # has any hashes in it, then we have a directory with directories
            # and can process grandchildren
            target = dig_index(path_within_container)
            break unless target.is_a?(Hash) && target.values.any? { |v| v.is_a?(Hash) }
          else
            path_within_container << segment.to_s

            matching_entries = dig_index(path_within_container)

            # if the path keys return nil then there is nothing at that path
            break if matching_entries.nil?
          end

          consumed += 1
        end

        @path_within_container = path_within_container

        consumed
      end

      def show(data)
        matching_entries = dig_index(path_within_container)

        data => { root:, segments:, physical: }

        path = root.make_path(segments)
        common = Container.common_attributes(data, container_path)

        if matching_entries.is_a?(Hash)
          Structs::DirectoryWrapper.new(
            path:,
            name: segments.last,
            **common
          )
        else
          # @type [::Zip::ZipEntry]
          entry = matching_entries

          name = Pathname(File.basename(entry.name))

          Structs::FileWrapper.new(
            path:,
            name: name.to_s,
            size: entry.size,
            mime: physical.mime_type(name),
            io: entry.get_input_stream,
            modified: container_path.mtime,
            **common
          )
        end
      end

      def list(data)
        matching_entries = dig_index(path_within_container)

        # should never happen - consume segments checked this
        raise unless matching_entries.is_a?(Hash)

        data => { root:, segments:, virtual:, physical:, paging: { limit: limit, offset: offset } }

        common = {
          data: root.additional_data(virtual.filtered_query),
          virtual_item_ids: virtual.filtered_query_results.map(&:id),
          physical_paths: [container_path]
        }

        sorted = matching_entries.sort_by { |key, _value| key.downcase }

        # now subset for paging and transform into structs
        children = sorted
          .drop(offset)
          .if_then(limit) { |x| x.take(limit) }
          .map { |key, entry|
          if entry.is_a?(Hash)
            Structs::Directory.new(
              name: key,
              path: root.make_path(*segments, key),
              **common
            )
          else
            name = File.basename(entry.name)

            Structs::File.new(
              name: name.to_s,
              path: root.make_path(*segments, name),
              size: entry.size,
              mime: physical.mime_type(Pathname(name)),
              **common
            )
          end
        }

        [children, sorted.count]
      end

      def have_children(children, _data)
        parent_entry = dig_index(path_within_container)
        children.map do |child|
          child_entry = parent_entry[child.name]

          # files should not be passed in as children to this method
          raise unless child_entry.is_a?(Hash)

          # does the child have any children?
          next child unless child_entry.any?

          child.new(has_children: true)
        end
      end

      def container_extension?(segment)
        segment.to_s.end_with?('.zip')
      end

      def mime_type
        MIME
      end

      private

      def build_index
        zip_file.entries.each do |entry|
          entry_name = entry.name
          # account for so-called directory entries
          is_directory = entry_name.end_with?('/')

          # automatically does not return empty strings (takes care of the directory case)
          entry_path = entry_name.split('/')

          # if it's a directory then we create any empty directory
          value = is_directory ? {} : entry

          @index.bury!(entry_path, value:, on_conflict: INDEXER_CONFLICT)
        end
      end

      # like dig but allows returning the index itself if the keys are empty
      def dig_index(keys)
        return @index if keys.empty?

        @index.dig(*keys)
      end
    end
  end
end
