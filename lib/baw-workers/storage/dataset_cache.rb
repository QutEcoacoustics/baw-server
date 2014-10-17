module BawWorkers
  module Storage
    # Provides access to dataset cache storage.
    class DatasetCache
      include BawWorkers::Storage::Common

      public

      # Create a new BawWorkers::Storage::DatasetCache.
      # @param [Array<String>] storage_paths
      # @return [void]
      def initialize(storage_paths)
        # array of top-level folder paths to store cached datasets
        @storage_paths = storage_paths

        @separator = '_'
        @extension_indicator = '.'
      end

      # Get the file name
      # @param [Hash] opts
      # @return [String] file name for stored file
      def file_name(opts = {})
        validate_saved_search_id(opts)
        validate_dataset_id(opts)
        validate_format(opts)

        result = opts[:saved_search_id].to_s + @separator +
            opts[:dataset_id].to_s +
            @extension_indicator + opts[:format].trim('.', '').to_s

        result.downcase
      end

      # Get file names
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts = {})
        [file_name(opts)]
      end

      # Construct the partial path.
      # @param [Hash] opts
      # @return [String] partial path
      def partial_path(opts = {})
        # no sub folders
        ''
      end

    end
  end
end
