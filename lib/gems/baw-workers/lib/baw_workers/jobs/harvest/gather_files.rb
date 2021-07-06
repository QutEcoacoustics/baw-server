# frozen_string_literal: true

require 'pathname'

module BawWorkers
  module Jobs
    module Harvest
      # Get a list of files to be harvested.
      class GatherFiles
        # Create a new BawWorkers::Jobs::Harvest::GatherFiles.
        # @param [Logger] logger
        # @param [BawWorkers::FileInfo] file_info_helper
        # @param [Array<String>] ext_include
        # @param [String] config_file_name
        # @return [BawWorkers::Jobs::Harvest::GatherFiles]
        def initialize(logger, file_info_helper, ext_include, config_file_name)
          @logger = logger
          @file_info_helper = file_info_helper

          @ext_include = ext_include #Settings.available_formats.audio
          @ext_exclude = ['completed', 'log', 'yml']
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

          if input_array.empty?
            msg = "'#{input}' must be a string or an array of strings."
            @logger.warn(@class_name) { msg }
          else
            input_array.each do |item|
              top_dir = if item.is_a?(String) && File.file?(item)
                          File.dirname(item)
                        else
                          item
                        end

              results.push(*process(item, top_dir, recurse))
            end
          end

          @logger.info(@class_name) { "Finished gathering files. Found #{results.size} file(s)." }

          results.compact
        end

        private

        def process(path, top_dir, recurse = true)
          dirs = []
          results = []

          path = File.expand_path(path)

          path = path.to_s if path.is_a? Pathname

          if path.is_a?(String) && File.file?(path)
            @logger.info(@class_name) { "Found file #{path}." }

            current_dir = File.dirname(path)
            files = [path]

          elsif path.is_a?(String) && File.directory?(path)
            @logger.info(@class_name) { "Found directory #{path}." }

            current_dir = path
            check_directory(current_dir)
            files = files_in_directory(current_dir)
            dirs = directories_in_directory(current_dir) if recurse

          else
            @logger.warn(@class_name) { "Not a recognised file or directory: #{path}." }
            return results
          end

          dir_settings = get_folder_settings(File.join(current_dir, @config_file_name))

          # process any files found
          files.each do |file|
            file_result = file(file, top_dir, dir_settings)
            results.push(file_result) unless file_result.blank?
          end

          if results.empty?
            @logger.debug(@class_name) { "No valid files in #{current_dir}." }
          else
            @logger.info(@class_name) { "Gathered info for #{results.size} valid files in #{current_dir}." }
          end

          # process any directories found
          dirs.each { |dir| results.push(*process(dir, top_dir, recurse)) }

          results
        end

        # Check properties for a directory.
        # @param [String] path directory
        # @return [Array<Hash>] directory
        def check_directory(path)
          unless File.directory?(path)
            msg = "'#{path}' is not a directory."
            @logger.error(@class_name) { msg }
            raise ArgumentError, msg
          end

          is_writable = File.writable?(path)
          is_writable_real = File.writable_real?(path)

          if !is_writable || !is_writable_real
            msg = "Found read-only directory: '#{path}'."
            @logger.error(@class_name) { msg }
            raise ArgumentError, msg
          end

          path
        end

        # Get file properties for a single file.
        # @param [String] path file
        # @param [String] top_dir base directory
        # @param [Hash] dir_settings
        # @return [Hash] file properties
        def file(path, top_dir, dir_settings = {})
          unless File.file?(path)
            msg = "'#{path}' is not a file."
            @logger.error(@class_name) { msg }
            raise ArgumentError, msg
          end

          path = File.expand_path(path)

          unless @file_info_helper.valid_ext?(path, @ext_include)
            @logger.warn(@class_name) { "Invalid extension #{path}." }
            return
          end

          @logger.debug(@class_name) { "Valid extension #{path}." }

          dir_settings = get_folder_settings(File.join(File.dirname(path), @config_file_name)) if dir_settings.blank?

          basic_info, advanced_info = file_info(path, dir_settings[:utc_offset])

          if basic_info.blank? || advanced_info.blank?
            @logger.warn(@class_name) { "Not enough information for #{path}." }
            {}
          else
            @logger.debug(@class_name) { "Complete information found for #{path}." }
            result = {}
            result = result.merge(basic_info).merge(dir_settings).merge(advanced_info)
            result[:file_rel_path] = Pathname.new(path).relative_path_from(Pathname.new(top_dir)).to_s
            result
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

          @logger.info(@class_name) { "Found #{files_in_dir.size} files in #{path}." }
          @logger.debug(@class_name) { "Files in #{path}: '#{files_in_dir.join(', ')}'." }

          files_in_dir
        end

        # Get all directories in a directory.
        # @param [String] path directory
        # @return [Array<String>] directories
        def directories_in_directory(path)
          dirs_in_dir = Dir.glob(File.join(path, '*/'))

          @logger.info(@class_name) { "Found #{dirs_in_dir.size} directories in #{path}." }
          @logger.debug(@class_name) { "Directories in #{path}: '#{dirs_in_dir.join(', ')}'." }

          dirs_in_dir
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
              utc_offset: config['utc_offset'],
              metadata: config['metadata']
            }

            if @file_info_helper.numeric?(folder_settings[:project_id]) &&
               @file_info_helper.numeric?(folder_settings[:site_id]) &&
               @file_info_helper.numeric?(folder_settings[:uploader_id]) &&
               @file_info_helper.time_offset?(folder_settings[:utc_offset])
              @logger.debug(@class_name) { "Harvest directory settings loaded from config file #{file}." }
              folder_settings
            else
              @logger.warn(@class_name) do
                "Harvest directory config file was not valid '#{file}'. Could not get all settings."
              end
              {}
            end
          rescue StandardError => e
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
end
