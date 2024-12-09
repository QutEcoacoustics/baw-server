# frozen_string_literal: true

module BawWorkers
  module Storage
    # Provides access to audio cache storage.
    class AudioCache
      include BawWorkers::Storage::Common

      # Create a new BawWorkers::Storage::AudioCache.
      # @param [Array<String>] storage_paths
      # @return [void]
      def initialize(storage_paths)
        # array of top-level folder paths to store cached audio
        @storage_paths = storage_paths
        @separator = '_'
        @extension_indicator = '.'
      end

      # Get the file name
      # @param [Hash] opts
      # @return [String] file name for stored file
      def file_name(opts)
        validate_uuid(opts)
        validate_start_offset(opts)
        validate_end_offset(opts)
        validate_channel(opts)
        validate_sample_rate(opts)
        validate_format(opts)

        result = opts[:uuid].to_s + @separator +
                 opts[:start_offset].to_f.to_s + @separator +
                 opts[:end_offset].to_f.to_s + @separator +
                 opts[:channel].to_i.to_s + @separator +
                 opts[:sample_rate].to_i.to_s +
                 @extension_indicator + opts[:format].trim('.', '').to_s
        result.downcase
      end

      # Get file names
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts)
        [file_name(opts)]
      end

      # Construct the partial path to an audio cache file.
      # @param [Hash] opts
      # @return [String] partial path to audio cache  file.
      def partial_path(opts)
        validate_uuid(opts)

        # prepend first two chars of uuid
        uuid_partitioning(opts[:uuid], partition_length: 2).downcase
      end
    end
  end
end
