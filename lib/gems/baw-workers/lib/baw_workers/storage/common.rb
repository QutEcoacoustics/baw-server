# frozen_string_literal: true

require 'active_support/concern'
require 'find'

module BawWorkers
  module Storage
    # Common storage functionality.
    module Common
      extend ActiveSupport::Concern

      module ClassMethods
      end

      # Get all possible full directories
      # @return [Array<String>]
      def possible_dirs
        @storage_paths
      end

      # Get all existing full directories
      # @return [Array<String>]
      def existing_dirs
        @storage_paths.select { |dir| Dir.exist? dir }
      end

      # Get all possible full paths for an audio recording.
      # @param [Hash] opts
      # @return [Array<String>]
      def possible_paths(opts)
        # file_names is implemented in each store.
        file_names(opts).map { |file_name| possible_paths_file(opts, file_name) }.flatten
      end

      # Get all possible full paths for a file name.
      # @param [Hash] opts
      # @param [String] file_name
      # @return [Array<String>]
      def possible_paths_file(opts, file_name)
        # partial_path is implemented in each store.
        @storage_paths.map { |path| File.join(path, partial_path(opts), file_name) }
      end

      # Get all possible full directory paths.
      # @param [Hash] opts
      # @return [Array<String>]
      def possible_paths_dir(opts)
        # partial_path is implemented in each store.
        @storage_paths.map { |path| File.join(path, partial_path(opts)) }
      end

      # Get all existing full paths for an audio recording.
      # @param [Hash] opts
      # @return [Array<String>]
      def existing_paths(opts)
        possible_paths(opts).select { |file| File.exist? file }
      end

      # Get file name, possible paths, existing paths.
      # @param [Hash] opts
      # @return [Hash]
      def path_info(opts)
        # file_names is implemented in each store.
        {
          file_names: file_names(opts),
          possible: possible_paths(opts),
          existing: existing_paths(opts)
        }
      end

      # Enumerate through all existing files using a block.
      # @return [void]
      def existing_files
        existing_dirs.each do |dir|
          Find.find(dir) do |path|
            if FileTest.directory?(path)
              if File.basename(path)[0] == '.'
                # Don't look any further into directories that start with a dot.
                Find.prune
              else
                next
              end
            elsif block_given?
              yield path
            end
          end
        end
      end

      private

      def validate_msg_base
        'Required parameter missing:'
      end

      def validate_msg_eq_or_gt
        'must be equal to or greater than'
      end

      def validate_msg_provided(opts)
        "Provided parameters: #{opts}"
      end

      # original

      def validate_uuid(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} uuid. #{provided}" unless opts.include? :uuid
        raise ArgumentError, "uuid must not be blank. #{provided}" if opts[:uuid].blank?

        unless BawWorkers::Validation.is_uuid?(opts[:uuid])
          raise ArgumentError, "uuid must be in hexidecimal format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx. #{provided}"
        end
      end

      def validate_datetime(opts)
        provided = validate_msg_provided(opts)
        unless opts.include? :datetime_with_offset
          raise ArgumentError, "#{validate_msg_base} datetime_with_offset. #{provided}"
        end
        raise ArgumentError, "datetime_with_offset must not be blank. #{provided}" if opts[:datetime_with_offset].blank?
        unless opts[:datetime_with_offset].is_a?(ActiveSupport::TimeWithZone)
          raise ArgumentError, "datetime_with_offset must be an ActiveSupport::TimeWithZone object. #{provided}"
        end
      end

      def validate_original_format(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} original_format. #{provided}" unless opts.include? :original_format
        raise ArgumentError, "original_format must not be blank. #{provided}" if opts[:original_format].blank?
      end

      # audio cache

      def validate_start_offset(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} start_offset. #{provided}" unless opts.include? :start_offset
        unless opts[:start_offset].to_f >= 0.0
          raise ArgumentError, "start_offset #{validate_msg_eq_or_gt} 0: #{opts[:end_offset]}. #{provided}"
        end
      end

      def validate_end_offset(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} end_offset. #{provided}" unless opts.include? :end_offset

        if opts[:start_offset].to_f >= opts[:end_offset].to_f
          raise ArgumentError,
            "end_offset (#{opts[:end_offset]}) must be greater than start_offset (#{opts[:start_offset]}). #{provided}"
        end
      end

      def validate_channel(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} channel. #{provided}" unless opts.include? :channel
        unless opts[:channel].to_i >= 0
          raise ArgumentError, "channel #{validate_msg_eq_or_gt} 0: #{opts[:channel]}. #{provided}"
        end
        unless opts[:channel].to_i.to_s == opts[:channel].to_s
          raise ArgumentError, "channel must be an integer: #{opts[:channel]}. #{provided}"
        end
      end

      def validate_sample_rate(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} sample_rate. #{provided}" unless opts.include? :sample_rate

        # sample rate must be either the native sample rate or on the list of allowed sample rates
        valid_sample_rates = BawAudioTools::AudioBase.valid_sample_rates(opts[:format], opts[:original_sample_rate])
        unless valid_sample_rates.include?(opts[:sample_rate].to_i)
          raise ArgumentError, "sample_rate (#{opts[:sample_rate]}) must be in #{valid_sample_rates}. #{provided}"
        end
      end

      def validate_format(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} format. #{provided}" unless opts.include? :format
        raise ArgumentError, "format must not be blank. #{provided}" if opts[:format].blank?
      end

      # spectrogram cache

      def validate_window(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} window. #{provided}" unless opts.include? :window

        unless BawAudioTools::AudioSox.window_options.include?(opts[:window].to_i)
          raise ArgumentError,
            "window must be in #{BawAudioTools::AudioSox.window_options}: #{opts[:window]}. #{provided}"
        end
      end

      def validate_colour(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} colour. #{provided}" unless opts.include? :colour

        return if BawAudioTools::AudioSox.colour_options.keys.include?(opts[:colour].to_sym)
        return if opts[:colour].to_sym == :w

        raise ArgumentError,
          "colour must be in #{BawAudioTools::AudioSox.colour_options.keys}: #{opts[:colour]}. #{provided}"
      end

      def validate_window_function(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} window function. #{provided}" unless opts.include? :window_function

        unless BawAudioTools::AudioSox.window_function_options.include?(opts[:window_function].to_s)
          raise ArgumentError,
            "window_function must be in #{BawAudioTools::AudioSox.window_function_options}: #{opts[:window_function]}. #{provided}"
        end
      end

      # analysis cache

      def validate_job_id(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} job_id. #{provided}" unless opts.include? :job_id
        raise ArgumentError, "job_id must not be blank. #{provided}" if opts[:job_id].blank?

        job_id = opts[:job_id].to_s.strip.downcase
        if job_id != BawWorkers::Storage::AnalysisCache::JOB_ID_SYSTEM
          unless job_id.to_i >= 1
            raise ArgumentError, "job_id #{validate_msg_eq_or_gt} 1: #{opts[:job_id]}. #{provided}"
          end
          unless job_id.to_i.to_s == job_id
            raise ArgumentError, "job_id must be an integer: #{opts[:job_id]}. #{provided}"
          end
        end
      end

      def validate_file_name(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} file_name. #{provided}" unless opts.include? :file_name
        raise ArgumentError, "file_name must not be nil. #{provided}" if opts[:file_name].nil?
      end

      def validate_sub_folders(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} sub_folders. #{provided}" unless opts.include? :sub_folders
        raise ArgumentError, "sub_folders must not be nil. #{provided}" if opts[:sub_folders].nil?
        raise ArgumentError, "sub_folders must be an Array. #{provided}" unless opts[:sub_folders].is_a?(Array)
      end

      # data set cache

      def validate_saved_search_id(opts)
        provided = validate_msg_provided(opts)
        raise ArgumentError, "#{validate_msg_base} saved_search_id. #{provided}" unless opts.include? :saved_search_id
        unless opts[:saved_search_id].to_i.positive?
          raise ArgumentError, "saved_search_id must be greater than 0: #{opts[:saved_search_id]}. #{provided}"
        end
      end
    end
  end
end
