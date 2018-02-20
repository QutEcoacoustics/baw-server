module Api
  module DirectoryRenderer

    # Returns the first file in `files`
    # Assumes all files exist.
    # @param [string[]] files
    # @param [Boolean] is_head_request
    # @return [void]
    def respond_with_file(files, is_head_request = false)
      existing_paths = files

      # it is possible to match more than one file (e.g. multiple storage dirs)
      # just return the first existing file
      file_path = existing_paths[0]

      ext = File.extname(file_path).trim('.', '')
      mime_type = Mime::Type.lookup_by_extension(ext)
      mime_type_s = mime_type.to_s
      file_size = FileSystems::Combined.size(file_path)

      if is_head_request
        head :ok, content_length: file_size, content_type: mime_type_s
      end

      # if sqlite, return blob
      FileSystems::Combined.check_and_open_sqlite(file_path) do |db, sqlite_path, sub_path|
        # we only want to send data if pulling blob from container db, otherwise use send_file method
        blob = FileSystems::Sqlite.get_blob(db, sqlite_path, sub_path)
        return send_data(blob, {filename: File.basename(sub_path), type: mime_type_s, disposition: 'inline'})
      end

      # else return file as normal
      send_file(file_path, {url_based_filename: true, type: mime_type_s, content_length: file_size})
    end

    # Returns a directory metadata object for the first directory supplied in `directories`
    # @param [String[]] directories
    # @param [String] base_directories - the directory to make paths relative to
    # @param [Hash] extra_payload - data to merge with the directory listing
    # @param [Boolean] is_head_request
    # @return [void]
    def respond_with_directory(directories, base_directories, url_base_path, extra_payload = {}, is_head_request = false, api_opts = {})
      existing_paths = directories

      # it is possible to match more than one dir (e.g. multiple storage dirs)
      # just return a file listing for the first existing dir
      dir_path = existing_paths[0]

      bases = {
        directory: base_directories[0],
        url_base_path: url_base_path
      }

      # api_opts's values are modified by reference in this call
      dir_listing = dir_info_children(dir_path, bases, api_opts)

      # merge dir listing with analysis job item
      result = extra_payload.merge(dir_listing)

      respond(result, is_head_request, api_opts)
    end

    # Returns a directory metadata object for the path in `directory`.
    # Intended to make a virtual resource look like another part of a virtual file system.
    # It assumes paging of children is already done!
    def respond_with_fake_directory(directory, children, base_directories, url_base_path, extra_payload = {}, is_head_request = false, api_opts = {})
      bases = {
          directory: base_directories[0],
          url_base_path: url_base_path
      }

      result = normalized_path_name(directory, bases)
      children_listing = children.map { |child| fake_dir_info(child['path'], bases) }
      result = result.merge({
                                type: 'directory',
                                children: children_listing
                            })
      result = extra_payload.merge(result)

      respond(result, is_head_request, api_opts)
    end

    private

    def respond(result, is_head_request, api_opts)

      # wrap with our standard api
      wrapped = Settings.api_response.build(:ok, result, api_opts)

      json_result = wrapped.to_json
      json_result_size = json_result.size.to_s

      add_header_length(json_result_size)

      if is_head_request
        head :ok, {content_length: json_result_size, content_type: Mime::Type.lookup('application/json')}
      else
        render json: json_result, content_length: json_result_size
      end
    end

    def dir_info_children(path, bases, paging)
      result = normalized_path_name(path, bases)

      children = []
      paging[:total] = 0
      children = dir_list(path, bases, paging) if FileSystems::Combined.directory_exists?(path)

      result.merge({
                       type: 'directory',
                       children: children
                   })
    end

    # Lists files in a directory.
    # *should* support pagination (skip & take).
    # This method is cursor based. Since we filter out files after the cursor indexes we can not guarantee a
    # consistent number of results returned.
    # DOES NOT GUARANTEE results.length == items.
    # DOES GUARANTEE results.length <= items.
    # @param [Hash] paging - a paging hash as returned by `parse_paging`
    # @param [string] path - the path to list contents for
    # @param [Hash] bases - a collection of bases used to normalize the results
    def dir_list(path, bases, paging)
      items = paging[:items]
      page = paging[:page]
      offset = paging[:offset]
      fail 'Disabling paging is not supported for a directory listing' if paging[:disable_paging]

      max_items = 1000

      child_paths, total = FileSystems::Combined.directory_list(path, items, offset, max_items)

      children = child_paths.map do |full_path|
        if FileSystems::Combined.directory_exists?(full_path)
          dir_info(full_path, bases)
        else
          raise "File should exist" unless FileSystems::Combined.file_exists?(full_path)
          file_info(full_path)
        end
      end

      paging[:total] = total
      paging[:warning] = "Only first #{max_items} results are available" if total >= max_items

      children
    end

    def dir_info(path, bases)
      result = normalized_path_name(path, bases)

      has_children = FileSystems::Combined.directory_has_children?(path)

      result.merge({
          type: 'directory',
          has_children: has_children
      })
    end

    def fake_dir_info(path, bases)
      result = normalized_path_name(path, bases)
      result.merge({
        type: 'directory',
        has_children: true
      })
    end

    def file_info(path)
      {
          mime: Mime::Type.lookup_by_extension(File.extname(path)[1..-1]).to_s,
          name: normalised_name(path),
          size_bytes: FileSystems::Combined.size(path),
          type: 'file'
      }
    end

    # Returns a normalized path and name for a given path.
    # It strips base[:directory], prepends base[:url_base_path] and then
    # returns :path (as a directory with a trailing slash) and :name as a filename only
    def normalized_path_name(path, bases)
      normalised_path = normalise_path(path, bases[:directory])

      # https://tools.ietf.org/html/rfc3986#section-3
      # paths for resource groups (e.g. directories) should always have a trailing slash
      #2.3.1 :006 > File.join("/a/","/b",  "/")  => "/a/b/"
      #2.3.1 :007 > File.join("/a/","/b/", "/")  => "/a/b/"
      #2.3.1 :008 > File.join("/a",  "b",  "/")  => "/a/b/"
      normalized_url_path = File.join(bases[:url_base_path], normalised_path, "/")

      # we use the normalized_url_path so that the name fragment always has a value that makes sense
      normalised_name = normalised_name(normalized_url_path)


      {path: normalized_url_path, name: normalised_name}
    end

    # Returns the last segment of the path, delimited by the path separator
    # Special cases for the root path '/' to return '/'.
    def normalised_name(path)
      path == '/' ? '/' : File.basename(path)
    end

    def normalise_path(path, base_directory)
      # NOTE: I do not understand this regex... it strips a base path... and then three folder levels as well
      # but why three folders? To which directory structure was this specialized for?
      #regex = /#{base_directory.gsub('/', '\/')}\/[^\/]+\/[^\/]+\/[^\/]+\/?/
      #regex = Regexp.new(base_directory + '/[^/]+/[^/]+/[^/]+/?')
      regex = Regexp.new(base_directory + '/?')
      path_without_base = path.gsub(regex, '')
      path_without_base.blank? ? '/' : "/#{path_without_base}"
    end

  end
end
