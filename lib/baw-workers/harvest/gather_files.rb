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

      # Get file properties for a directory.
      # @param [String] input directory path
      # @param [Boolean] recurse
      # @return [Array<Hash>] file properties
      def directory(input, recurse = true)
        unless File.directory?(input)
          msg = "'#{input}' is not a directory."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end
        result = directories([input], recurse)

        @logger.info(@class_name) {
          "Finished directory #{input}."
        }

        @logger.debug(@class_name) {
          "Directory result: #{result}."
        }

        result
      end

      # Get file properties for multiple directories.
      # @param [Array<String>] input directory paths
      # @param [Boolean] recurse
      # @return [Array<Hash>] file properties
      def directories(input, recurse = true)
        unless input.is_a?(Array)
          msg = "'#{input}' is not an array."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end


        # get all directories
        dirs = input.map { |dir|
          if File.directory?(dir)
            expanded_dir = File.expand_path(dir)
            if recurse
              # include the top level directory
              found_dirs = Dir.glob(File.join(expanded_dir, '**')).concat([expanded_dir])
              @logger.debug(@class_name) { "Found directories '#{found_dirs.join(', ')}'." }
              found_dirs
            else
              @logger.debug(@class_name) { "Found directory #{expanded_dir}." }
              [expanded_dir]
            end
          else
            @logger.warn(@class_name) { "'#{dir}' is not a directory." }
            []
          end
        }.flatten

        # check that at least one directory was found.
        if dirs.size < 1
          msg = "Could not find harvester to do path(s): #{input}"
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end

        # get properties for all valid audio files
        all_files = []
        dirs.each do |dir|
          items_in_dir = Dir.glob(File.join(dir, '*'))
          files_in_dir = items_in_dir.select { |f| File.file?(f) }
          @logger.debug(@class_name) { "Found files '#{files_in_dir.join(', ')}'." }
          file_props = files(files_in_dir)
          all_files.push(*file_props)
        end

        @logger.info(@class_name) {
          "Finished #{input.size} directories. Included #{dirs.size} looking #{recurse ? 'recursively' : 'at top only'}."
        }

        @logger.debug(@class_name) {
          "Finished '#{input.join(', ')}' directories '#{dirs.join(', ')}': #{all_files}."
        }

        all_files
      end

      # Get properties for a file.
      # @param [String] input file path
      # @return [Hash] file properties if it is a valid audio file
      def file(input)
        unless File.file?(input)
          msg = "'#{input}' is not a file."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end
        result = files([input].flatten)
        output = (result.size == 1) ? result[0] : {}

        @logger.info(@class_name) {
          "Finished file #{input}."
        }

        @logger.debug(@class_name) {
          "File result: #{output}."
        }

        output
      end

      # Get properties for all valid audio files in this directory.
      # @param [Array<String>] input file paths
      # @return [Array<Hash>] valid files
      def files(input)
        unless input.is_a?(Array)
          msg = "'#{input}' is not an array."
          @logger.error(@class_name) { msg }
          fail ArgumentError, msg
        end

        folder_settings = get_folder_settings(File.join(input, @config_file_name))

        @logger.debug(@class_name) { "Checking files: '#{input.join(', ')}'." }

        # filter files to only valid audio files
        filtered_files = input.reduce([]) do |aggregate, item|

          if File.file?(item) && @file_info_helper.valid_ext?(item, @ext_include)
            @logger.debug(@class_name) {
              "Valid file: #{item}."
            }
            basic_info = @file_info_helper.basic(item)
            advanced_info = @file_info_helper.advanced(item, folder_settings[:utc_offset])

            if basic_info.blank? || advanced_info.blank?
              @logger.warn(@class_name) {
                "Could not get properties for file #{item}: Basic: #{basic_info}. Advanced: #{advanced_info}."
              }
            else
              result = basic_info.merge(advanced_info)
              @logger.debug(@class_name) { "Got properties for file #{item}: #{result}." }
              aggregate.push(result)
            end
          else
            @logger.info(@class_name) {
              "Invalid file: #{item}."
            }
          end

          aggregate
        end

        @logger.info(@class_name) {
          "Finished files. Included #{filtered_files.size} of #{input.size} files."
        }

        @logger.debug(@class_name) {
          "Finished files '#{input.join(', ')}': #{filtered_files}."
        }

        filtered_files
      end

      # Get folder settings.
      # If the config file does not exist, that's ok,
      # some files might have that info in their file names
      # so the settings file might not exist
      # @param [string] input
      # @return [Hash]
      def get_folder_settings(input)
        return {} unless File.exists?(input)
        return {} unless File.size?(input)

        begin
          config = YAML.load_file(input)

          folder_settings = {
              project_id: config['project_id'],
              site_id: config['site_id'],
              uploader_id: config['uploader_id'],
              utc_offset: config['utc_offset']
          }

          return {} unless @file_info_helper.numeric?(folder_settings[:project_id])
          return {} unless @file_info_helper.numeric?(folder_settings[:site_id])
          return {} unless @file_info_helper.numeric?(folder_settings[:uploader_id])
          return {} unless @file_info_helper.time_offset?(folder_settings[:utc_offset])

          folder_settings
        rescue
          {}
        end
      end

    end
  end
end