module FileSystems
  SQLITE_EXTENSION = '.sqlite3'.freeze

  # Represents a combined physical and sqlite file system abstraction
  module Combined
    def file_exists(path)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.file_exists?(sqlite_path, sub_path)
      end

      Physical.file_exists?(path)
    end

    def directory_exists?(path)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.directory_exists?(sqlite_path, sub_path)
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
    def directory_list(path, items, offset, max_items)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.directory_list(sqlite_path, sub_path, items, offset, max_items)
      end

      Physical.directory_list(path, items, offset, max_items)
    end

    def directory_has_children?(path)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.directory_has_children?(sqlite_path, sub_path)
      end

      Physical.directory_has_children?(path)
    end

    def size(path)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.size(sqlite_path, sub_path)
      end

      Physical.size(path)
    end

    def get_blob(path)
      has_sqlite?(path) do |sqlite_path, sub_path|
        return Sqlite.get_blob(sqlite_path, sub_path)
      end

      Physical.get_blob(path)
    end

    private

    # Determines if given string has an .sqlite extension in it.
    # If it does, it returns two strings, the path to the sqlite file, and the sub file
    def has_sqlite?(path, &sqlite)
      paths = path.split(SQLITE_EXTENSION)

      return paths unless paths.length > 1

      paths = [paths[0] + SQLITE_EXTENSION, paths[1]]
      sqlite.call(*paths)

      paths
    end
  end
end
