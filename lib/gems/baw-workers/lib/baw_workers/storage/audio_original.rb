# frozen_string_literal: true

module BawWorkers
  module Storage
    # Provides access to original audio storage.
    class AudioOriginal
      include BawWorkers::Storage::Common

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
      # @param [Hash] opts
      # @return [string] file name
      def file_name_utc(opts)
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
      def file_names(opts)
        [file_name_10(opts), file_name_utc(opts)]
      end

      # Construct the partial path to an original audio file.
      # @param [Hash] opts
      # @return [String] partial path to original audio file.
      def partial_path(opts)
        validate_uuid(opts)

        opts[:uuid][0, 2].downcase
      end

      # Extract information from a file name.
      # @param [String] file_path
      # @return [Hash] info
      def parse_file_path(file_path)
        file_name = File.basename(file_path)
        file_name_split = file_name.split('_')

        datetime_with_offset, original_format = file_name_split[1].split('.')

        if datetime_with_offset.length == 11
          # 120302-1505
          date = Time.utc(
            "20#{datetime_with_offset[0..1]}",
            datetime_with_offset[2..3],
            datetime_with_offset[4..5],
            datetime_with_offset[7..8],
            datetime_with_offset[9..10]
          ).advance(hours: -10).in_time_zone
        elsif datetime_with_offset.length == 16
          # 20120302-050537Z
          date = Time.utc(
            datetime_with_offset[0..3],
            datetime_with_offset[4..5],
            datetime_with_offset[6..7],
            datetime_with_offset[9..10],
            datetime_with_offset[11..12],
            datetime_with_offset[13..14]
          ).in_time_zone
        else
          date = nil
          raise ArgumentError, "Invalid file name date format: #{file_name}."
        end

        opts = {
          uuid: file_name_split[0],
          datetime_with_offset: date,
          original_format: original_format
        }

        validate_uuid(opts)
        validate_datetime(opts)
        validate_original_format(opts)

        opts
      end
    end
  end
end
