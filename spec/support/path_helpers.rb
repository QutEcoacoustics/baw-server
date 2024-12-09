# frozen_string_literal: true

module PathHelpers
  module Example
    # @deprecated Use #link_original_audio instead.
    def create_original_audio(options, example_file_name, new_name_style = false, delete_other = false)
      options = options.to_h unless options.is_a?(Hash)
      # ensure :datetime_with_offset is an ActiveSupport::TimeWithZone object
      if options.include?(:datetime_with_offset) && options[:datetime_with_offset].is_a?(ActiveSupport::TimeWithZone)
        # all good - no op
      elsif options.include?(:datetime_with_offset) && options[:datetime_with_offset].end_with?('Z')
        options[:datetime_with_offset] = Time.zone.parse(options[:datetime_with_offset])
      else
        raise ArgumentError,
          "recorded_date must be a UTC time (i.e. end with Z), given '#{options[:datetime_with_offset]}'."
      end

      original_possible_paths = BawWorkers::Config.original_audio_helper.possible_paths(options)

      file_to_make = new_name_style ? original_possible_paths.first : original_possible_paths.second
      file_to_delete = new_name_style ? original_possible_paths.second : original_possible_paths.first

      File.delete(file_to_delete) if delete_other && File.exist?(file_to_delete)
      FileUtils.mkpath File.dirname(file_to_make)
      FileUtils.cp example_file_name, file_to_make

      file_to_make
    end

    # Adds a file to our original audio directory for testing.
    # For performance reasons it actually symlinks to the file.
    # @return [Pathname]
    def link_original_audio(target:, uuid:, datetime_with_offset:, original_format:)
      raise ArgumentError, 'target must be a Pathname' unless target.is_a?(Pathname)
      unless datetime_with_offset.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, 'datetime_with_offset must be a ActiveSupport::TimeWithZone'
      end

      original_possible_paths = BawWorkers::Config.original_audio_helper.possible_paths({
        uuid:,
        datetime_with_offset:,
        original_format:
      })

      path = Pathname(original_possible_paths.last)

      path.delete if path.exist?
      path.parent.mkpath

      logger.info(
        "Linking #{target} to #{path}",
        uuid:,
        datetime_with_offset:,
        original_format:
      )

      path.make_symlink(target)
      path
    end

    def link_original_audio_to_audio_recordings(*audio_recordings, target:)
      audio_recordings.flatten.each do |audio_recording|
        raise ArgumentError, 'audio_recording must be an AudioRecording' unless audio_recording.is_a?(AudioRecording)

        link_original_audio(
          target:,
          uuid: audio_recording.uuid,
          datetime_with_offset: audio_recording.recorded_date,
          original_format: audio_recording.original_format_calculated
        )
      end
    end

    def create_analysis_result_directory(analysis_jobs_item, path)
      unless analysis_jobs_item.is_a?(AnalysisJobsItem)
        raise ArgumentError,
          'analysis_jobs_item must be an AnalysisJobItem'
      end

      full_path = analysis_jobs_item.results_absolute_path / path
      full_path.mkpath
    end

    def create_analysis_result_file(analysis_jobs_item, path, content: nil)
      unless analysis_jobs_item.is_a?(AnalysisJobsItem)
        raise ArgumentError,
          'analysis_jobs_item must be an AnalysisJobItem'
      end
      raise ArgumentError, 'path must be a Pathname' unless path.is_a?(Pathname)

      full_path = analysis_jobs_item.results_absolute_path / path

      full_path.parent.mkpath
      full_path.write(content)

      full_path
    end

    def link_analysis_result_file(analysis_jobs_item, path, target:)
      unless analysis_jobs_item.is_a?(AnalysisJobsItem)
        raise ArgumentError,
          'analysis_jobs_item must be an AnalysisJobItem'
      end
      raise ArgumentError, 'path must be a Pathname' unless path.is_a?(Pathname)
      raise ArgumentError, 'target must be a Pathname' unless target.is_a?(Pathname)
      raise ArgumentError, 'target must exist' unless target.exist?

      full_path = analysis_jobs_item.results_absolute_path / path

      full_path.delete if full_path.exist?

      full_path.parent.mkpath

      full_path.make_symlink(target)
      full_path
    end

    def clear_original_audio
      paths = Settings.paths.original_audios

      clear_directories(paths)
    end

    def clear_spectrogram_cache
      paths = Settings.paths.cached_spectrograms

      clear_directories(paths)
    end

    def clear_audio_cache
      paths = Settings.paths.cached_audios

      clear_directories(paths)
    end

    def clear_analysis_cache
      paths = Settings.paths.cached_analysis_jobs

      clear_directories(paths)
    end

    def clear_harvester_to_do
      paths = [harvest_to_do_path]
      clear_directories(paths, '/data/test/harvester_to_do')
    end

    def clear_directories(directories, sanity_check = 'test')
      directories.each do |path|
        raise "Will not delete #{path} because it does not contain '#{sanity_check}'" unless path =~ /#{sanity_check}/

        # some of these dirs are referenced on shared file systems (e.g. Docker)
        # thus, don't remove dir, clear contents
        path = Pathname(path)
        if path.exist?
          path.children.each { |entry|
            entry.rmtree unless entry.basename.to_s == '.gitkeep'
          }
        else
          path.mkpath
        end
      end
    end

    def expect_empty_directories(directories)
      directories = Array(directories)
      aggregate_failures do
        directories.each do |path|
          path = Pathname(path)
          next unless path.exist?

          expect(path.empty?).to(be(true), lambda {
            children = path.children.each(&:to_s).join("\n")

            "Expected #{path} to be empty but it contained:\n#{children}"
          })
        end
      end
    end

    def make_original_audio
      paths = Settings.paths.original_audios

      paths.each do |path|
        raise "Will not create #{path} because it does not contain 'test'" unless path =~ /_test_/

        FileUtils.mkdir_p path
      end
    end

    def get_cached_audio_paths(options)
      options = options.to_h unless options.is_a?(Hash)
      BawWorkers::Config.audio_cache_helper.possible_paths(options)
    end

    def get_cached_spectrogram_paths(options)
      options = options.to_h unless options.is_a?(Hash)
      BawWorkers::Config.spectrogram_cache_helper.possible_paths(options)
    end

    def copy_test_audio_check_csv
      csv_file_example = Fixtures.audio_check_csv

      FileUtils.mkpath(custom_temp)
      csv_file = File.join(custom_temp, '_audio_check_to_do.csv')

      FileUtils.cp(csv_file_example, csv_file)

      csv_file
    end

    # @param path [Pathname]
    # @param harvest [Harvest]
    # @param target_name [String] The basename of the file to create. If nil the basename of the path will be used.
    # @param sub_directories [Array<String>]
    # @return [HarvestPathsHelper]
    def copy_fixture_to_harvest_directory(path, harvest, target_name: nil, sub_directories: [].freeze)
      raise unless path.is_a?(Pathname)
      raise unless harvest.is_a?(Harvest)
      raise unless path.absolute? && path.exist?

      target_directory = harvest.upload_directory.join(*sub_directories)
      target_directory.mkpath
      target_name ||= path.basename.to_s
      target = target_directory.join(target_name)
      FileUtils.copy_file(path, target)

      HarvestPathsHelper.new(
        target,
        target.relative_path_from(Settings.root_to_do_path),
        target.relative_path_from(harvest.upload_directory),
        target_name
      )
    end

    class HarvestPathsHelper
      # @return [Pathname]
      attr_reader :absolute_path
      # @return [Pathname]
      attr_reader :harvester_relative_path
      # @return [Pathname]
      attr_reader :harvest_relative_path
      # @return [String]
      attr_reader :filename

      def initialize(absolute_path, harvester_relative_path, harvest_relative_path, filename)
        @absolute_path = absolute_path
        @harvester_relative_path = harvester_relative_path
        @harvest_relative_path = harvest_relative_path
        @filename = filename
      end
    end
  end
end
