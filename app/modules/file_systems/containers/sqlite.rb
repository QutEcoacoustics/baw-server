# frozen_string_literal: true

module FileSystems
  # This is an abstraction over the standard file system that allows for SQLite 3 files to be used as container
  # formats for files.
  module Containers
    # A container that represents a SQLite3 file.
    class Sqlite
      MIME = 'application/x-sqlite3'

      attr_accessor :container_path

      attr_reader :db, :path_within_container

      def mime_type
        MIME
      end

      def consume_segments(sub_segments, _data)
        @db = Support.open_database(container_path)

        consumed = 0
        path_within_container = Pathname('/')

        sub_segments.each do |segment|
          if segment.children?
            break unless Support.directory_exists?(db, path_within_container)
          elsif segment.grandchildren?

            break unless Support.directory_has_directories?(db, path_within_container)
          else
            path_within_container /= segment.to_s

            break unless Support.path_exists?(db, path_within_container)
          end

          consumed += 1
        end

        @path_within_container = path_within_container

        consumed
      end

      def show(data)
        data => { root:, segments:, physical: }

        path = root.make_path(segments)
        name = Pathname(File.basename(path))
        common = Container.common_attributes(data, container_path)

        if Support.file_exists?(db, path_within_container)
          blob = Support.get_blob(db, path_within_container)
          mime = physical.mime_type(name)

          Structs::FileWrapper.new(
            path:,
            name: name.to_s,
            size: blob.length,
            mime:,
            io: StringIO.new(blob),
            modified: container_path.mtime,
            **common
          )
        else
          Structs::DirectoryWrapper.new(
            path:,
            name: name.to_s,
            **common
          )
        end
      end

      def list(data)
        data => {segments:, root:, physical:, paging: { limit: limit, offset: offset }}

        items, total = Support.directory_list(db, path_within_container, limit:, offset:)

        items.map do |item|
          item => [item_path_in_container, size]
          is_dir = item_path_in_container.end_with?('/')

          item_path_in_container
            .delete_suffix('/')
            .delete_prefix('/') => item_path_in_container

          item_path = Pathname(item_path_in_container)

          name = item_path.basename
          path = root.make_path(segments, name)
          common = Container.common_attributes(data, container_path)

          if is_dir
            Structs::Directory.new(
              path:,
              name: name.to_s,
              # this is a flat file system, any "directory" can only exist if it has children
              has_children: true,
              **common
            )
          else
            Structs::File.new(
              path:,
              name: name.to_s,
              size:,
              mime: physical.mime_type(name),
              **common
            )
          end
        end => children

        [children, total]
      end

      def have_children(children, _data)
        # noop: have_children is already true
        children
      end

      def container_extension?(segment)
        segment.to_s.end_with?('.sqlite3')
      end

      # Sqlite queries for a file-system like databases
      module Support
        FILES_TABLE = 'files'
        FILES_PATH = 'path'
        FILES_BLOB = 'blob'

        module_function

        def required_version
          Gem::Version.new('3.18.0')
        end

        # Check we've been provided with a recent version of SQLite.
        # This should be called on application initialization
        def self.check_version
          # hard coded dependency for sqlite v3.18.0 or higher.
          # Note: this is not a dependency we can encode in the Gemfile
          # because the sqlite gem depends on the system installed sqlite binary
          # Note2: I've found SQLite3::SQLITE_VERSION_NUMBER and SQLite3::SQLITE_VERSION
          # to be unreliable indicators of the version actually used!

          require 'sqlite3'
          version = Gem::Version.new(SQLite3::Database.new(':memory:').get_first_value('SELECT sqlite_version();'))

          return unless version < required_version

          raise "Sqlite3 lib version #{version} is below required version #{required_version}"
        end

        # the replace function caters for the root path case where the path is '/'
        MATCH_DIR = "#{FILES_PATH} GLOB replace((:path || '/*'), '//', '/')".freeze
        MATCH_DIRS_WITH_DIRS = "#{FILES_PATH} GLOB replace((:path || '/*/*'), '//', '/')".freeze

        FILE_EXISTS_QUERY = <<~SQL.squish
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1)
        SQL

        DIRECTORY_EXISTS_QUERY = <<~SQL.squish
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{MATCH_DIR} LIMIT 1)
        SQL

        PATH_EXISTS_QUERY = <<~SQL.squish
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE
          #{FILES_PATH} = :path
          OR
          #{MATCH_DIR}
           LIMIT 1)
        SQL

        DIRECTORY_HAS_DIRECTORIES_QUERY = <<~SQL.squish
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{MATCH_DIRS_WITH_DIRS} LIMIT 1)
        SQL

        GET_BLOB_QUERY = <<~SQL.squish
          SELECT #{FILES_BLOB} FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1
        SQL

        # This query returns all the paths that match, and the total count of paths that match
        # as the first result
        LIST_FILES_QUERY = <<~SQL.squish
          WITH filtered AS (
            /* Select the directories */
            SELECT DISTINCT(
              /* cut down the file paths to look like directories */
              substr(#{FILES_PATH}, 0, (length(:path) +  1) + instr(substr(#{FILES_PATH}, (length(:path) +  1)), '/'))
            ) AS #{FILES_PATH}, 0 AS size
            FROM #{FILES_TABLE}
            WHERE #{MATCH_DIRS_WITH_DIRS}
            UNION ALL
            /* Select the files */
            SELECT #{FILES_PATH}, length(#{FILES_BLOB}) AS size
            FROM #{FILES_TABLE}
            WHERE #{MATCH_DIR} AND NOT (#{MATCH_DIRS_WITH_DIRS})
            ORDER BY #{FILES_PATH}
          )
          SELECT NULL AS #{FILES_PATH}, COUNT(path) AS size
          FROM filtered
          UNION ALL
          SELECT *
          FROM (
            SELECT #{FILES_PATH}, size
            FROM filtered
            LIMIT :limit
            OFFSET :offset
          )
        SQL

        # def get_file_length_query
        #   <<~SQL.squish
        #     SELECT length(#{FILES_BLOB}) FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1
        #   SQL
        # end

        def file_exists?(db, path)
          exists(db, FILE_EXISTS_QUERY, path)
        end

        def directory_exists?(db, path)
          exists(db, DIRECTORY_EXISTS_QUERY, path)
        end

        def path_exists?(db, path)
          exists(db, PATH_EXISTS_QUERY, path)
        end

        def directory_has_directories?(db, path)
          exists(db, DIRECTORY_HAS_DIRECTORIES_QUERY, path)
        end

        # @return [Array<Array(String, Integer)>, Integer] the list of paths and the total count of paths
        def directory_list(db, path, limit:, offset:)
          unless limit.is_a?(Integer) && limit.positive?
            raise ArgumentError, "limit must be a positive integer but was #{limit}"
          end

          unless offset.is_a?(Integer) && offset >= 0
            raise ArgumentError, "offset must be an integer and greater than 0 but was #{offset}"
          end

          path = path&.to_s
          path = '/' if path.blank?

          paths = db.execute(LIST_FILES_QUERY, { path:, limit:, offset: })

          # take out first row, and the second column to get total count
          paths => [first_row, *paths]
          count = first_row.second

          # zero-index is the first-column of each row
          [paths, count]
        end

        def size(db, path)
          db.get_first_value(get_file_length_query, { path: path.to_s })
        end

        def get_blob(db, path)
          db.get_first_value(GET_BLOB_QUERY, { path:  path.to_s })
        end

        # Open a sqlite db. This function get memoized but only for the duration of the request.
        def open_database(sqlite_path)
          db = SQLite3::Database.new(sqlite_path, { readonly: true })

          raise 'Sqlite3 database not opened as readonly!' unless db.readonly?

          db
        end

        #
        # Helpers
        #

        def make_file_filter(param_name, include_sub_directories)
          base_filter = "#{FILES_PATH} LIKE :#{param_name} || '_%'"
          this_dir_filter = "AND #{FILES_PATH} NOT LIKE :#{param_name} || '_%/%'"
          base_filter + (include_sub_directories ? '' : this_dir_filter)
        end

        # @param [SQLite3::Database] db
        # @param [string] query
        def exists(db, query, path)
          db.get_first_value(query, { path: path.to_s }) == 1
        end
      end
    end

    Sqlite::Support.check_version
  end
end
