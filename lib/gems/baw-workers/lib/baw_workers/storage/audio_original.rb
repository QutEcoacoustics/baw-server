# frozen_string_literal: true

module BawWorkers
  module Storage
    # Provides access to original audio storage.
    class AudioOriginal
      include BawWorkers::Storage::Common

      NAME_REGEX_ALL_VERSIONS = /(?<uuid>[-a-z0-9]{36})(?:_(?<date>[-0-9Z]+))?\.(?<extension>\w+)/

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
      # This is our V1 format.
      # @deprecated
      # @param [Hash] opts
      # @return [String] file name
      def file_name_10(opts)
        validate_uuid(opts)
        validate_datetime(opts)
        validate_original_format(opts)

        result = opts[:uuid].to_s + @separator +
                 opts[:datetime_with_offset].utc.advance(hours: 10).strftime('%y%m%d-%H%M') +
                 @extension_indicator + opts[:original_format].trim('.', '').to_s

        result.downcase
      end

      # Create a file name. This filename is always explicitly in UTC.
      # This is our V2 format.
      # @deprecated
      # @param [Hash] opts
      # @return [String] file name
      def file_name_utc(opts)
        validate_uuid(opts)
        validate_datetime(opts)
        validate_original_format(opts)
        uuid = opts[:uuid].to_s.downcase
        date = opts[:datetime_with_offset].utc.strftime('%Y%m%d-%H%M%S').downcase
        ext = opts[:original_format].trim('.', '').to_s.downcase

        "#{uuid}#{@separator}#{date}Z#{@extension_indicator}#{ext}"
      end

      # Create a file name. This file name uses the uuid only.
      # Removing the date from the name makes re-dating audio much easier in the database
      # since we don't have to physically move the file.
      # This is our V3 format.
      def file_name_uuid(opts)
        validate_uuid(opts)
        validate_original_format(opts)

        uuid = opts[:uuid].to_s.downcase
        extension = opts[:original_format].trim('.', '').to_s.downcase

        uuid + @extension_indicator + extension
      end

      # Get file names.
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts)
        [file_name_uuid(opts), file_name_10(opts), file_name_utc(opts)]
      end

      # Construct the partial path to an original audio file.
      # @param [Hash] opts
      # @return [String] partial path to original audio file.
      def partial_path(opts)
        validate_uuid(opts)

        uuid_partitioning(opts[:uuid], partition_length: 2).downcase
      end
    end
  end
end
