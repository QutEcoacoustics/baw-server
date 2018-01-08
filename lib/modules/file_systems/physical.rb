module FileSystems
  module Physical
    def file_exists?(path)
      File.file?(path)
    end

    def directory_exists?(path)
      Diretory.directory?(path)
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
      children = []
      listing = Dir.foreach(path)
      filtered_count = 0

      listing.each do |item|
        # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
        next if item == '.' || item == '..' || item.start_with?('.')

        # special case - stop scanning large dirs
        if filtered_count >= max_items
          break;
        end

        filtered_count += 1

        # skip
        next if filtered_count <= offset

        # break
        next if children.length >= items

        # take
        full_path = File.join(path, item)
        children.push(full_path)
      end
    end

    def directory_has_children?(sqlite_path, path)
      has_children = false
      Dir.foreach(path) do |item|
        # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
        next if item == '.' || item == '..' || item.start_with?('.')

        has_children = true
        break
      end

      has_children
    end

    def size(path)
      File.size(path)
    end

    def get_blob(path)
      File.read(path)
    end

  end
end