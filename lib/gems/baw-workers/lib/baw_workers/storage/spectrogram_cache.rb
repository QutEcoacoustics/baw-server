# frozen_string_literal: true

module BawWorkers
  module Storage
    # Provides access to spectrogram cache storage.
    class SpectrogramCache
      include BawWorkers::Storage::Common

      # Create a new BawWorkers::Storage::SpectrogramCache.
      # @param [Array<String>] storage_paths
      # @return [void]
      def initialize(storage_paths)
        # array of top-level folder paths to store cached spectrograms
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
        validate_window(opts)
        validate_window_function(opts)
        validate_colour(opts)
        validate_format(opts)

        # TODO: Add in future? brightness, contrast, overlap

        opts[:uuid].to_s.downcase + @separator +
          opts[:start_offset].to_f.to_s + @separator +
          opts[:end_offset].to_f.to_s + @separator +
          opts[:channel].to_i.to_s + @separator +
          opts[:sample_rate].to_i.to_s + @separator +
          opts[:window].to_i.to_s + @separator +
          opts[:window_function].to_s + @separator +
          opts[:colour].to_s +
          @extension_indicator + opts[:format].trim('.', '').to_s
      end

      # Get file names
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts)
        [file_name(opts)]
      end

      # Construct the partial path
      # @param [Hash] opts
      # @return [String] partial path
      def partial_path(opts)
        validate_uuid(opts)

        # prepend first two chars of uuid
        opts[:uuid][0, 2].downcase
      end

      # Extract information from a file name.
      # @param [String] file_path
      # @return [Hash] info
      def parse_file_path(file_path)
        file_name = File.basename(file_path)
        file_name_split = file_name.split('_')

        colour, format = file_name_split[7].split('.')

        opts = {
          uuid: file_name_split[0],
          start_offset: file_name_split[1].to_f,
          end_offset: file_name_split[2].to_f,
          channel: file_name_split[3].to_i,
          sample_rate: file_name_split[4].to_i,
          window: file_name_split[5].to_i,
          window_function: file_name_split[6],
          colour: colour,
          format: format
        }

        validate_uuid(opts)
        validate_start_offset(opts)
        validate_end_offset(opts)
        validate_channel(opts)
        validate_sample_rate(opts)
        validate_window(opts)
        validate_window_function(opts)
        validate_colour(opts)
        validate_format(opts)

        opts
      end
    end
  end
end
