module FileSystems
  # This is an abstraction over the standard file system that allows for SQLite 3 files to be used as container
  # formats for files.
  class Sqlite
    class << self
      FILES_TABLE = 'files'
      FILES_PATH = 'path'
      FILES_BLOB = 'blob'

      def required_version
        Gem::Version.new('3.18.0')
      end

      # Check we've been provided with a recent version of SQLite.
      # This should be called on application initialization
      def check_version
        # hard coded dependency for sqlite v3.18.0 or higher.
        # Note: this is not a dependency we can encode in the Gemfile
        # because the sqlite gem depends on the system installed sqlite binary
        # Note2: I've found SQLite3::SQLITE_VERSION_NUMBER and SQLite3::SQLITE_VERSION
        # to be unreliable indicators of the version actually used!

        require 'sqlite3'
        version = Gem::Version.new(SQLite3::Database.new(':memory:').get_first_value('SELECT sqlite_version();'))

        if version < required_version
          raise "Sqlite3 lib version #{version} is below required version #{required_version}"
        end
      end


      def file_exists
        <<~SQL
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1)
        SQL
      end

      def directory_exists
        <<~SQL
          SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{make_file_filter('path', true)} LIMIT 1)
        SQL
      end

      def list_files_query(path)
        length = path.length
        # This query returns all the paths that match, and the total count of paths that match
        # as the first result
        <<~SQL
          WITH filtered AS (
            SELECT DISTINCT(
              substr(#{FILES_PATH}, 0, #{length + 1} + instr(substr(#{FILES_PATH}, #{length + 1}), '/'))
            ) AS #{FILES_PATH}
            FROM #{FILES_TABLE}
            WHERE #{FILES_PATH} LIKE :#{FILES_PATH} || '_%/%'
            UNION ALL
            SELECT #{FILES_PATH}
            FROM #{FILES_TABLE}
            WHERE #{make_file_filter('path', false)} AND #{FILES_PATH} NOT LIKE '%/.%'
            ORDER BY #{FILES_PATH}
          )
          SELECT COUNT(path) FROM filtered
          UNION ALL
          SELECT #{FILES_PATH} FROM (            
            SELECT #{FILES_PATH}
            FROM filtered
            LIMIT :limit            
            OFFSET :offset
          )
        SQL
      end

      def get_file_length_query
        <<~SQL
          SELECT length(#{FILES_BLOB}) FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1
        SQL
      end

      def get_file_blob_query
        <<~SQL
          SELECT #{FILES_BLOB} FROM #{FILES_TABLE} WHERE #{FILES_PATH} = :path LIMIT 1
        SQL
      end


      def file_exists?(db, sqlite_path, path)
        exists(db, file_exists, path)
      end

      def directory_exists?(db, sqlite_path, path)
        exists(db, directory_exists, path)
      end

      def directory_list(db, sqlite_path, path, items, offset, max_items)
        path = '/' if path.blank?
        paths = db.execute(list_files_query(path), {path: path, limit: items, offset: offset})

        count = paths.shift

        # zero-index is the first-column of each row
        full_paths = paths.map{|row| row[0] }.map{|path| sqlite_path + path }
        [full_paths, count[0]]
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
        base_filter = "#{FILES_PATH} LIKE :#{param_name} || '_%'"
        this_dir_filter = "AND #{FILES_PATH} NOT LIKE :#{param_name} || '_%/%'"
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