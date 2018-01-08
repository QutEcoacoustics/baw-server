module FileSystems
  # This is an abstraction over the standard file system that allows for SQLite 3 files to be used as container
  # formats for files.
  module Sqlite
    def file_exists?(sqlite_path, path)
      db = open_database(sqlite_path)

      exists(db, FILE_EXISTS, path)
    end

    def directory_exists?(sqlite_path, path)
      db = open_database(sqlite_path)

      exists(db, DIRECTORY_EXISTS, path)
    end

    def directory_list(sqlite_path, path, items, offset, max_items)
      db = open_database(sqlite_path)

      paths = db.execute(LIST_FILES_QUERY, {path: path, limit: items, offset: offset})

      paths.select { |path| sqlite_path + path }
    end

    def directory_has_children?(sqlite_path, path)
      # We've built this model on the premise that the SQLite file contains a flat file system - a directory can not
      # exist without children.
      true
    end

    def size(sqlite_path, path)
      db = open_database(sqlite_path)

      db.get_first_value(GET_FILE_LENGTH, {path: path})
    end

    def get_blob(sqlite_path, path)
      db = open_database(sqlite_path)

      db.get_first_value(GET_FILE_BLOB, {path: path})
    end

    private

    FILES_TABLE = 'files'
    FILES_PATH = 'path'
    FILES_BLOB = 'blob'
    FILE_EXISTS <<-SQL
      SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1)
SQL
    DIRECTORY_EXISTS <<-SQL
      SELECT EXISTS(SELECT 1 FROM #{FILES_TABLE} WHERE #{make_file_filter('path', true)} LIMIT 1)
SQL
    LIST_FILES_QUERY <<-SQL
      SELECT #{FILES_PATH}
      FROM #{FILES_TABLE}
      WHERE #{make_file_filter('path', false)} AND @path NOT LIKE '%/.%' 
      OFFSET @offset
      LIMIT @limit
SQL
    GET_FILE_LENGTH <<-SQL
      SELECT length(#{FilesBlob}) FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1
SQL
    GET_FILE_BLOB <<-SQL
      SELECT #{FilesBlob} FROM #{FILES_TABLE} WHERE #{FILES_PATH} = @path LIMIT 1
SQL


    def make_file_filter(param_name, include_sub_directories)
      base_filter = "#{FilesPath} LIKE @#{param_name} || '_%'"
      this_dir_filter = "AND #{FilesPath} NOT LIKE @#{param_name} || '_%/%'"
      base_filter + (include_sub_directories ? '' : this_dir_filter)
    end

    # Open a sqlite db. This function get memoized but only for the duration of the request.
    def open_database(sqlite_path)
      db = SQLite3::Database.new(sqlite_path, {readonly: true})

      raise "Sqlite3 database not opened as readonly!" unless db.readonly?

      db
    end
    memoize :open_database

    # @param [SQLite3::Database] db
    # @param [string] query
    def exists(db, query, path)
      db.get_first_value(query, {path: path}) == 1
    end

  end
end