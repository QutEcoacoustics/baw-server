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
      file_size = File.size(file_path)

      if is_head_request
        head :ok, content_length: file_size, content_type: mime_type_s
      else
        send_file(file_path, url_based_filename: true, type: mime_type_s, content_length: file_size)
      end
    end

    # Returns a directory metadata object for the first directory supplied in `directories`
    # @param [String[]] directories
    # @param [String] base_directories - the directory to make paths relative to
    # @param [Hash] extra_payload - data to merge with the directory listing
    # @param [Boolean] is_head_request
    # @return [void]
    def respond_wtth_directory(directories, base_directories, extra_payload, is_head_request = false)
      existing_paths = directories

      # it is possible to match more than one dir (e.g. multiple storage dirs)
      # just return a file listing for the first existing dir
      dir_path = existing_paths[0]

      dir_listing = dir_info_children(dir_path, base_directories[0])

      # merge dir listing with analysis job item
      result = extra_payload.merge(dir_listing)

      # wrap with our standard api
      wrapped = Settings.api_response.build(:ok, result)

      json_result = wrapped.to_json
      json_result_size = json_result.size.to_s

      add_header_length(json_result_size)

      if is_head_request
        head :ok, {content_length: json_result_size, content_type: Mime::Type.lookup('application/json')}
      else
        render json: json_result, content_length: json_result_size
      end
    end

    private

    def dir_info_children(path, base_directory)
      result = normalized_path_name(path, base_directory)

      children = []
      children = dir_list(path, base_directory) if Dir.exist?(path)

      result.merge({
                       type: 'directory',
                       children: children
                   })
    end

    def dir_list(path, base_directory)
      children = []

      max_items = 50
      items_count = 0

      Dir.foreach(path) do |item|
        # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
        next if item == '.' || item == '..' || item.start_with?('.')

        full_path = File.join(path, item)

        children.push(dir_info(full_path, base_directory)) if File.directory?(full_path)
        children.push(file_info(full_path)) if File.file?(full_path) && !File.directory?(full_path)

        items_count = items_count + 1
        break if items_count >= max_items
      end

      children
    end

    def dir_info(path, base_directory)
      result = normalized_path_name(path, base_directory)


      has_children = false
      Dir.foreach(path) do |item|
        # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
        next if item == '.' || item == '..' || item.start_with?('.')

        has_children = true
        break
      end

      result.merge({
                       type: 'directory',
                       has_children: has_children
                   })
    end

    def file_info(path)
      {
          name: normalised_name(path),
          type: 'file',
          size_bytes: File.size(path),
          mime: Mime::Type.lookup_by_extension(File.extname(path)[1..-1]).to_s
      }
    end

    def normalized_path_name(path, base_directory)
      normalised_path = normalise_path(path, base_directory)
      normalised_name = normalised_name(normalised_path)

      {path: normalised_path, name: normalised_name}
    end

    def normalised_name(path)
      path == '/' ? '/' : File.basename(path)
    end

    def normalise_path(path, base_directory)
      path_without_base = path.gsub(/#{base_directory.gsub('/', '\/')}\/[^\/]+\/[^\/]+\/[^\/]+\/?/, '')
      path_without_base.blank? ? '/' : "/#{path_without_base}"
    end

  end
end
