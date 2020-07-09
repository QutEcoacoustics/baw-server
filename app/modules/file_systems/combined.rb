# frozen_string_literal: true

module FileSystems
  SQLITE_EXTENSION = '.sqlite3'

  # Represents a combined physical and sqlite file system abstraction
  class Combined
    class << self
      extend Memoist
      FileSystems::Physical
      FileSystems::Sqlite

      def file_exists?(path)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.file_exists?(db, sqlite_path, sub_path)
        end

        Physical.file_exists?(path)
      end

      def directory_exists?(path)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.directory_exists?(db, sqlite_path, sub_path)
        end

        Physical.directory_exists?(path)
      end

      # Lists files in a directory.
      # *should* support pagination (skip & take).
      # This method is cursor based. Since we filter out files after the cursor indexes we can not guarantee a
      # consistent number of results returned.
      # DOES NOT GUARANTEE results.length == items.
      # DOES GUARANTEE results.length <= items.
      # @param [int] items - the number of items per page
      # @param [string] path - the path to list contents for
      # @param [int] offset - the number of items to skip
      # @param [int] max_items - the maximum number of items that will be enumerated through
      # @return [string[],int] - the paths that match and a total count
      def directory_list(path, items, offset, max_items)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.directory_list(db, sqlite_path, sub_path, items, offset, max_items)
        end

        Physical.directory_list(path, items, offset, max_items)
      end

      def directory_has_children?(path)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.directory_has_children?(db, sqlite_path, sub_path)
        end

        Physical.directory_has_children?(path)
      end

      def size(path)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.size(db, sqlite_path, sub_path)
        end

        Physical.size(path)
      end

      def get_blob(path)
        check_and_open_sqlite path do |db, sqlite_path, sub_path|
          return Sqlite.get_blob(db, sqlite_path, sub_path)
        end

        Physical.get_blob(path)
      end

      # Determines if given string has an .sqlite extension in it.
      # If it does, it returns two strings, the path to the sqlite file, and the sub file
      def check_and_open_sqlite(path, &sqlite)
        index = path.index(SQLITE_EXTENSION)
        return [path, nil] if index.nil?

        index += SQLITE_EXTENSION.length
        db_path = path.slice(0, index)
        sub_path = if index == path.length - 1
                     '/'
                   else
                     path.slice(index, path.length - index)
                   end

        db = open_sqlite_inner(db_path)

        sqlite.call db, db_path, sub_path if db

        [db_path, sub_path]
      end

      # memoize the sqlite file path check and the database open
      def open_sqlite_inner(path)
        Sqlite.open_database(path) if File.file?(path)
      end

      # I'm disabling the memoization on a hunch that it is caching the result for the application life time. I've
      # got do idea how to confirm this though.
      #memoize :open_sqlite_inner
    end
  end
end
