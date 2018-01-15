module FileSystems
  # This is an abstraction over the standard file system that allows for SQLite 3 files to be used as container
  # formats for files.
  class Sqlite
    class << self
      FILES_TABLE = 'files'
      FILES_PATH = 'path'
      FILES_BLOB = 'blob'

      def file_exists
        <<-SQL
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1)
        SQL
      end

      def directory_exists
        <<-SQL
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{make_file_filter('path', true)} LIMIT 1)
        SQL
      end

      def list_files_query
        # This query returns all the paths that match, and the total count of paths that match
        # as the ?last? result
        <<-SQL
          WITH filtered AS(
            SELECT #{FILES_PATH}
            FROM #{FILES_TABLE}
            WHERE #{make_file_filter('path', false)} AND @path NOT LIKE '%/.%'
            ORDER BY #{FILES_PATH}
          )
          SELECT #{FILES_PATH} FROM filtered
          OFFSET @offset
          LIMIT @limit
          UNION ALL
          SELECT COUNT(path) FROM filtered
        SQL
      end

      def get_file_length_query
        <<-SQL
          SELECT length(#{FilesBlob}) FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1
        SQL
      end

      def get_file_blob_query
        <<-SQL
          SELECT #{FilesBlob} FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1
        SQL
      end


      def file_exists?(db, sqlite_path, path)
        exists(db, file_exists, path)
      end

      def directory_exists?(db, sqlite_path, path)
        exists(db, directory_exists, path)
      end

      def directory_list(db, sqlite_path, path, items, offset, max_items)
        paths = db.execute(list_files_query, {path: path, limit: items, offset: offset})

        count = paths.pop

        return paths.select {|path| sqlite_path + path}, count
      end

      def directory_has_children?(db, sqlite_path, path)
        # We've built this model on the premise that the SQLite file contains a flat file system - a directory can not
        # exist without children.
        true
      end

      def size(db, sqlite_path, path)
        db.get_first_value(get_file_length_query, {path: path})
      end

      def get_blob(db, sqlite_path, path)
        db.get_first_value(get_file_blob_query, {path: path})
      end

      # Open a sqlite db. This function get memoized but only for the duration of the request.
      def open_database(sqlite_path)
        db = SQLite3::Database.new(sqlite_path, {readonly: true})

        raise "Sqlite3 database not opened as readonly!" unless db.readonly?

        db
      end

      #
      # Helpers
      #

      def make_file_filter(param_name, include_sub_directories)
        base_filter = "#{FilesPath} LIKE @#{param_name} || '_%'"
        this_dir_filter = "AND #{FilesPath} NOT LIKE @#{param_name} || '_%/%'"
        base_filter + (include_sub_directories ? '' : this_dir_filter)
      end

      # @param [SQLite3::Database] db
      # @param [string] query
      def exists(db, query, path)
        db.get_first_value(query, {path: path}) == 1
      end
    end
  end
end