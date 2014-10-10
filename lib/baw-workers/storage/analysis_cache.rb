module BawWorkers
  module Storage
    # Provides access to Analysis Cache storage.
    class AnalysisCache
      include BawWorkers::Storage::Common

      FILE_NAME_NOT_ALLOWED = /[^0-9a-zA-Z_\-\.]/

      public

      # Create a new BawWorkers::Storage::AnalysisCache.
      # @param [Array<String>] storage_paths
      # @return [void]
      def initialize(storage_paths)
        # array of top-level folder paths to store cached analysis results
        @storage_paths = storage_paths
        @separator = '_'
        @extension_indicator = '.'
      end

      # Get the file name
      # @param [Hash] opts
      # @return [String] file name for stored file
      def file_name(opts = {})
        validate_result_file_name(opts)

        opts[:result_file_name].gsub(FILE_NAME_NOT_ALLOWED, @separator).downcase
      end

      # Get file names
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts = {})
        [file_name(opts)]
      end

      # Construct the partial path to an analysis result file.
      # @param [Hash] opts
      # @return [String] partial path to analysis result file.
      def partial_path(opts = {})
        validate_uuid(opts)
        validate_analysis_id(opts)

        first = opts[:uuid][0, 2].downcase
        second = opts[:uuid].downcase
        third = opts[:analysis_id].gsub(FILE_NAME_NOT_ALLOWED, @separator).downcase

        File.join(first, second, third)
      end

    end
  end
end
