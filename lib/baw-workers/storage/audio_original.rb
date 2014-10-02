module BawWorkers
  module Storage
    class AudioOriginal
      include BawWorkers::Storage::Common

      public

      # Create a new BawWorkers::Storage::AudioOriginal.
      # @param [Array<String>] storage_paths
      # @return [void]
      def initialize(storage_paths)
        # array of top-level folder paths to store original audio
        @storage_paths = storage_paths

        @separator = '_'
        @extension_indicator = '.'
      end

      # Create a file name. This file name is by convention always in utc offset +1000.
      # @deprecated
      # @param [Hash] opts
      # @return [string] file name
      def file_name_10(opts = {})
        validate_uuid(opts)
        validate_datetime(opts)
        validate_original_format(opts)

        result = opts[:uuid].to_s + @separator +
            opts[:datetime_with_offset].utc.advance(hours: 10).strftime('%y%m%d-%H%M') +
            @extension_indicator + opts[:original_format].trim('.', '').to_s

        result.downcase
      end

      # Create a file name. This filename is always explicitly in UTC.
      # @param [Hash] opts
      # @return [string] file name
      def file_name_utc(opts = {})
        validate_uuid(opts)
        validate_datetime(opts)
        validate_original_format(opts)

        result = opts[:uuid].to_s.downcase + @separator +
            opts[:datetime_with_offset].utc.strftime('%Y%m%d-%H%M%S').downcase + 'Z' +
            @extension_indicator + opts[:original_format].trim('.', '').to_s.downcase

        result
      end

      # Get file names.
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts = {})
        [file_name_10(opts), file_name_utc(opts)]
      end

      # Construct the partial path to an original audio file.
      # @param [Hash] opts
      # @return [String] partial path to original audio file.
      def partial_path(opts = {})
        validate_uuid(opts)

        opts[:uuid][0, 2].downcase
      end

    end
  end
end