# frozen_string_literal: true

require 'pathname'

module BawWorkers
  module Storage
    # Provides access to analysis cache storage.
    class AnalysisCache
      include BawWorkers::Storage::Common

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
      def file_name(opts)
        validate_file_name(opts)

        BawWorkers::Validation.normalise_path(opts[:file_name], nil)
      end

      # Get file names
      # @param [Hash] opts
      # @return [Array<String>]
      def file_names(opts)
        [file_name(opts)]
      end

      # Construct the partial path to an analysis result file.
      # Backwards compatible version.
      # If a script_id is present then a more partitioned directory structure is
      # used and it will support script sub directories.
      # @param [Hash] opts
      # @return [String, Array<String>] partial path to analysis result file.
      def partial_path(opts)
        validate_job_id(opts)
        validate_uuid(opts)
        validate_script_id(opts) => has_script_id
        validate_sub_folders(opts)

        # <job_id>/<partition>/<full guid>/<script_id?>/<subfolder(s)?>

        job_id = opts[:job_id].to_s.strip.downcase
        uuid = opts[:uuid].downcase
        partition = uuid_partitioning(uuid, partition_length: 2)
        sub_folder = File.join(*opts[:sub_folders])

        partial_path = File.join(job_id, partition, uuid, sub_folder)
        partial_path = BawWorkers::Validation.normalise_path(partial_path, nil)

        return partial_path unless has_script_id

        script_id = opts[:script_id].to_s.strip.downcase
        script_partial_path = File.join(job_id, partition, uuid, script_id, sub_folder)
        script_partial_path = BawWorkers::Validation.normalise_path(script_partial_path, nil)

        [script_partial_path, partial_path]
      end

      # Construct the path to an analysis results root folder.
      # @param [Hash] opts
      # @return [String] path to analysis results root folder.
      def job_path(opts)
        validate_job_id(opts)

        # ./<job_id>

        job_id = opts[:job_id].to_s.strip.downcase

        partial_path = File.join(job_id)

        BawWorkers::Validation.normalise_path(partial_path, nil)
      end

      # Get all possible root paths for an analysis job.
      # @param [Hash] opts
      # @return [Array<String>]
      def possible_job_paths_dir(opts)
        # partial_path is implemented in each store.
        @storage_paths.map { |path| File.join(path, job_path(opts)) }
      end
    end
  end
end
