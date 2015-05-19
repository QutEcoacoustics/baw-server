module BawWorkers
  module Harvest
    # Get a list of files to be harvested.
    class GatherFiles

      # Create a new BawWorkers::Harvest::GatherFiles.
      # @param [Logger] logger
      # @param [BawWorkers::FileInfo] file_info_helper
      # @param [Array<String>] ext_include
      # @param [String] config_file_name
      # @return [BawWorkers::Harvest::GatherFiles]
      def initialize(logger, file_info_helper, ext_include, config_file_name)
        @logger = logger
        @file_info_helper = file_info_helper

        @ext_include = ext_include #Settings.available_formats.audio
        @ext_exclude = %w(completed log yml)
        @config_file_name = config_file_name

        @class_name = self.class.name
      end

      # Get file properties for a file, directory, or array of files or directories.
      # @param [String] input file, directory, or array of files or directories
      # @param [Boolean] recurse look in sub folders
      # @return [Array<Hash>] file properties
      def run(input, recurse = true)
        results = []

        @logger.info(@class_name) { 'Gathering files.' }

        input_array = []
        input_array = [input] if input.is_a?(String)
        input_array = input if input.is_a?(Array)

        if input_array.size > 0
          input_array.each { |item| results.push(*process(item, recurse)) }
        else
          msg = "'#{input}' must be a string or an array of strings."
          @logger.warn(@class_name) { msg }
        end

        @logger.info(@class_name) { "Finished gathering files. Found #{results.size} file(s)." }

        results
      end

      private

      def process(input_string, recurse = true)
        results = []

        if input_string.is_a?(String) && File.file?(input_string)
          @logger.info(@class_name) { "Found file #{input_string}." }
          results.push(file(input_string))
        elsif input_string.is_a?(String) && File.directory?(input_string)
          path = File.expand_path(input_string)
          results.push(*directory(path))

          if recurse
            found_dirs = Dir.glob(File.join(path, '*/'))

            @logger.debug(@class_name) { "Looking recursively. Found #{found_dirs.size} directories in #{path}." }
            @logger.debug(@class_name) { "Directories in #{path}: '#{found_dirs.join(', ')}'." }

            found_dirs.each { |dir| results.push(*process(dir)) }
          end
        else
          @logger.warn(@class_name) { "Not a recognised file or directory: #{input_string}." }
        end

        results
      end

      # Get file properties for a directory. Does not recurse.
      # @param [String] path directory
      # @return [Array<Hash>] file properties
      def directory(path)
        unless File.directory?(path)
          msg = "'#{path}' is not a directory."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end

        path = File.expand_path(path)

        files_in_dir = files_in_directory(path)

        dir_settings = get_folder_settings(File.join(path, @config_file_name))

        files = []
        files_in_dir.each do |item|
          file_result = file(item, dir_settings)
          files.push(file_result) unless file_result.blank?
        end

        if files.size > 0
          @logger.info(@class_name) { "Gathered info for #{files.size} valid files in #{path}." }
        else
          @logger.debug(@class_name) { "No valid files in #{path}." }
        end

        files
      end

      # Get file properties for a single file.
      # @param [String] path file
      # @param [Hash] dir_settings
      # @return [Hash] file properties
      def file(path, dir_settings = {})
        unless File.file?(path)
          msg = "'#{path}' is not a file."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end

        path = File.expand_path(path)

        unless @file_info_helper.valid_ext?(path, @ext_include)
          @logger.debug(@class_name) { "Invalid extension #{path}." }
          return {}
        end

        @logger.debug(@class_name) { "Valid extension #{path}." }

        dir_settings = get_folder_settings(File.join(File.dirname(path), @config_file_name)) if dir_settings.blank?

        basic_info, advanced_info = file_info(path, dir_settings[:utc_offset])

        if basic_info.blank? || advanced_info.blank?
          @logger.debug(@class_name) { "Not enough information for #{path}." }
          {}
        else
          @logger.debug(@class_name) { "Complete information found for #{path}." }
          basic_info.merge(dir_settings).merge(advanced_info)
        end
      end

      # Get info for file.
      # @param [String] file
      # @param [String] utc_offset
      # @return [Array] basic_info, advanced_info
      def file_info(file, utc_offset)
        basic_info, advanced_info = nil

        begin
          basic_info = @file_info_helper.basic(file)
          advanced_info = @file_info_helper.advanced(file, utc_offset)

          msg_props = "properties for file #{file} using offset #{utc_offset}: Basic: #{basic_info}. Advanced: #{advanced_info}."

          if basic_info.blank? || advanced_info.blank?
            @logger.info(@class_name) { "Could not get #{msg_props}" }
          else
            @logger.debug(@class_name) { "Successfully got #{msg_props}" }
          end

        rescue StandardError => e
          @logger.error(@class_name) {
            "Problem getting details for #{file} using utc offset '#{utc_offset}': #{format_error(e)}"
          }
        end

        [basic_info, advanced_info]
      end

      # Get all files in a directory.
      # @param [String] path directory
      # @return [Array<String>] files
      def files_in_directory(path)
        items_in_dir = Dir.glob(File.join(path, '*'))
        files_in_dir = items_in_dir.select { |f| File.file?(f) }

        msg = "Looking in #{path}. Found #{files_in_dir.size} files."
        @logger.debug(@class_name) { msg } if files_in_dir.size > 0
        @logger.debug(@class_name) { msg } if files_in_dir.size < 1
        @logger.debug(@class_name) { "Files in #{path}: '#{files_in_dir.join(', ')}'." }

        files_in_dir
      end

      # Get folder settings.
      # If the config file does not exist, that's ok,
      # some files might have that info in their file names
      # so the settings file might not exist
      # @param [string] file
      # @return [Hash]
      def get_folder_settings(file)
        unless File.file?(file)
          @logger.debug(@class_name) { "Harvest directory config file was not found '#{file}'." }
          return {}
        end

        unless File.size?(file)
          @logger.warn(@class_name) { "Harvest directory config file had no content '#{file}'." }
          return {}
        end

        begin
          config = YAML.load_file(file)

          folder_settings = {
              project_id: config['project_id'],
              site_id: config['site_id'],
              uploader_id: config['uploader_id'],
              utc_offset: config['utc_offset']
          }

          if @file_info_helper.numeric?(folder_settings[:project_id]) &&
              @file_info_helper.numeric?(folder_settings[:site_id]) &&
              @file_info_helper.numeric?(folder_settings[:uploader_id]) &&
              @file_info_helper.time_offset?(folder_settings[:utc_offset])
            @logger.debug(@class_name) { "Harvest directory settings loaded from config file #{file}." }
            folder_settings
          else
            @logger.warn(@class_name) { "Harvest directory config file was not valid '#{file}'. Could not get all settings." }
            {}
          end

        rescue StandardError=> e
          @logger.warn(@class_name) { "Harvest directory config file was not valid '#{file}'. #{format_error(e)}" }
          {}
        end
      end

      # Format error.
      # @param [Exception] e error
      # @return [String] formatted error
      def format_error(e)
        "Error: #{e}\nBacktrace: #{e.backtrace.first(8).join("\n")}"
      end
    end
  end
end