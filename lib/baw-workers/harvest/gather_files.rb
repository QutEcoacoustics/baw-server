module BawWorkers
  module Harvest
    # Get a list of files to be harvested.
    class GatherFiles

      # include common methods
      include BawWorkers::Common

      # Create a new BawWorkers::Harvest::GatherFiles.
      # @param [Logger] logger
      # @param [BawWorkers::FileInfo] file_info_helper
      # @param [Array<String>] ext_include
      # @param [String] config_file_name
      # @return [BawWorkers::Harvest::GatherFiles]
      def initialize(logger, file_info_helper, ext_include, config_file_name)
        @logger = logger
        @file_info_helper = file_info_helper

        #@harvest_paths = Settings.paths.harvester_to_do
        @ext_include = ext_include #Settings.available_formats.audio
        @ext_exclude = %w(completed log yml)
        @config_file_name = config_file_name #Settings.config_file_name
        #@upload_dir = Settings.paths.progressive_upload_directory
      end

      # Get files that can be harvested.
      # @param [String, Array<String>] harvest_locations
      # @param [String] upload_dir_name
      # @return [Array<Hash>] files
      def all_files(harvest_locations, upload_dir_name)

        every_dir = all_dirs(harvest_locations)
        valid_dirs = valid_dirs(every_dir, upload_dir_name)

        valid_files = []
        valid_dirs[:config_file].each { |dir| valid_files.push(*valid_files(dir, true)) }
        valid_dirs[:upload_dir].each { |dir| valid_files.push(*valid_files(dir, false)) }

        # required:
        # file_path, file_name, extension, access_time, change_time, modified_time,
        # data_length_bytes, project_id, site_id, uploader_id, utc_offset,
        # recorded_date

        # optional:
        # prefix, suffix

        valid_files
      end

      # Get all valid subdirectories.
      # @param [String, Array<String>] dirs
      # @return [Array<String>] dirs
      def all_dirs(dirs)
        output = []
        if dirs.is_a?(Array)
          dirs.each { |item| output.push(*all_dirs(item)) }

        elsif File.directory?(dirs)
          dirs = Dir.glob('**/*').select { |f| File.directory? f }
          output.push(*dirs)

        else
          msg = "Could not find harvester_to_do path(s): #{dirs}"
          @logger.error(get_class_name) { msg }
          fail Exceptions::HarvesterConfigurationError, msg
        end

        output
      end

      # Get all config files and upload dir.
      # @param [Array<String>] dirs
      # @param [String] upload_dir_name
      # @return [Array<Hash>] config file dirs and upload dirs
      def valid_dirs(dirs, upload_dir_name)
        output_config_file = []
        output_upload_dir = []
        upload_dir_expanded = File.expand_path(upload_dir_name)

        dirs.each do |dir|
          config_file = File.join(dir, @config_file_name)

          if File.file?(config_file) && File.exists?(config_file)
            output_config_file.push(dir)

          elsif File.directory?(dir) && File.expand_path(dir) == upload_dir_expanded
            output_upload_dir.push(dir)

          else
            @logger.warn(get_class_name) {
              "Directory #{dir} did not contain a config file and is not the progressive upload directory."
            }

          end
        end

        {
            config_file: output_config_file,
            upload_dir: output_upload_dir
        }
      end

      # Get all valid files in this dir and subdirs.
      # @param [String] dir
      # @param [Boolean] config_file_found
      # @return [Array<Hash>] valid files
      def valid_files(dir, config_file_found = false)
        folder_settings = config_file_found ? get_folder_settings(File.join(dir, @config_file_name)) : {}

        all_files = Dir[File.join(dir, '**/*')]

        filtered_files = all_files.reduce([]) do |aggregate, item|

          if valid_ext?(item)
            begin
              file_info = file_properties(item, folder_settings)
              aggregate.push(file_info)
            rescue => e
              @logger.error(get_class_name) {
                "Error getting properties for file #{item}: #{e.message} => #{e.backtrace}"
              }
            end
          end

          aggregate
        end

        @logger.info(get_class_name) {
          "Found valid directory #{dir}. #{filtered_files.size} of #{all_files.size} files included."
        }

        filtered_files
      end

      # Get file properties.
      # @param [String] file
      # @param [Hash] folder_settings
      # @return [Hash] file properties
      def file_properties(file, folder_settings = {})
        basic_info = @file_info_helper.basic(file)

        if basic_info.empty?
          msg = "Could not get basic info for #{file}."
          @logger.error(get_class_name) { msg }
          fail BawWorkers::Exceptions::HarvesterError, msg
        end

        if folder_settings.blank?
          file_name_info = info_from_name(File.basename(file))
        else
          file_name_info = info_from_name(File.basename(file), folder_settings[:utc_offset])
        end

        if file_name_info.empty?
          msg = "Could not get info from file name for #{file}."
          @logger.error(get_class_name) { msg }
          fail BawWorkers::Exceptions::HarvesterError, msg
        end

        info = basic_info.merge(folder_settings).merge(file_name_info)

        @logger.debug(get_class_name) {
          "File #{file} details #{info}"
        }

        info
      end

      # Check that this file's extension is valid.
      # @param [String] file
      # @return [Boolean] valid extension
      def valid_ext?(file)
        ext = File.extname(file).trim('.', '').downcase

        if @ext_include.include?(ext)
          true

        elsif @ext_exclude.include?(ext)
          false

        else
          # log any unexpected skipped extensions
          @logger.warn(get_class_name) {
            "Excluding #{file}. Extension #{ext} was not in include list #{@ext_include} and not in exclude list #{@ext_exclude}."
          }

          false
        end

      end

      # Get the audio recording start date and time.
      # @return [Hash] Parsed info from file name
      # @param [string] file_name
      def info_from_name(file_name, utc_offset = nil)

        additional_info = parse_all_info_filename(file_name)
        @logger.debug(get_class_name) {
          "Results from parse_all_info_filename for #{file_name}: #{additional_info}."
        }

        if additional_info.empty?
          additional_info = parse_datetime_offset_filename(file_name)
          @logger.debug(get_class_name) {
            "Results from parse_datetime_offset_filename for #{file_name}: #{additional_info}."
          }
        end

        if additional_info.empty? && !utc_offset.blank?
          additional_info = parse_datetime_filename(file_name, utc_offset)
          @logger.debug(get_class_name) {
            "Results from parse_datetime_filename for #{file_name}: #{additional_info}."
          }
        end

        if additional_info.empty? && !utc_offset.blank?
          additional_info = parse_datetime_suffix_filename(file_name, utc_offset)
          @logger.debug(get_class_name) {
            "Results from parse_datetime_suffix_filename for #{file_name}: #{additional_info}."
          }
        end

        if additional_info.blank?
          utc_offset_required = utc_offset.blank? ? 'utc_offset might be required' : "utc_offset was #{utc_offset}"
          fail ArgumentError, "Could not parse file name #{file_name} (#{utc_offset_required})"
        end

        additional_info
      end

      # Get info from upload dir file name.
      # @param [String] file_name
      # @return [Hash] info from file name
      def parse_all_info_filename(file_name)
        result = {}
        # valid: p1_s2_u3_d20140101_t235959Z.mp3, p000_s00000_u00000_d00000000_t000000Z.0, p9999_s9_u9999999_d99999999_t999999Z.dnsb48364JSFDSD
        file_name.scan(/^p(\d+)_s(\d+)_u(\d+)_d(\d{4})(\d{2})(\d{2})_t(\d{2})(\d{2})(\d{2})Z\.([a-zA-Z0-9]+)$/) do |project_id, site_id, uploader_id, year, month, day, hour, min, sec, extension|
          raw = {project_id: project_id, site_id: site_id, uploader_id: uploader_id, year: year, month: month, day: day, hour: hour, min: min, sec: sec, ext: extension}
          @logger.debug(get_class_name) { "Raw parse from parse_all_info_filename for #{file_name}: #{raw}." }

          result[:recorded_date] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, '+0').iso8601(3)
          result[:extension] = extension
          result[:project_id] = project_id.to_i
          result[:site_id] = site_id.to_i
          result[:uploader_id] = uploader_id.to_i
          result[:utc_offset] = '+0'
        end
        result
      end

      # Get info from file name using specified utc offset.
      # @param [String] file_name
      # @param [String] utc_offset
      # @return [Hash] info from file name
      def parse_datetime_filename(file_name, utc_offset)
        result = {}
        # valid: prefix_20140101_235959.mp3, a_00000000_000000.a, a_99999999_999999.dnsb48364JSFDSD
        file_name.scan(/^(.*)(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.([a-zA-Z0-9]+)$/) do |prefix, year, month, day, hour, min, sec, extension|
          raw = {prefix: prefix, year: year, month: month, day: day, hour: hour, min: min, sec: sec, ext: extension}
          @logger.debug(get_class_name) { "Raw parse from parse_datetime_filename for #{file_name}: #{raw}." }

          result[:recorded_date] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset).iso8601(3)
          result[:prefix] = prefix.blank? ? prefix : prefix.trim('_', '')
          result[:extension] = extension
          result[:utc_offset] = utc_offset
        end
        result
      end

      # Get info from file name that includes utc offset..
      # @param [String] file_name
      # @return [Hash] info from file name
      def parse_datetime_offset_filename(file_name)
        result = {}
        # valid: prefix_20140101_235959+10.mp3, a_00000000_000000+00.a, a_99999999_999999+9999.dnsb48364JSFDSD
        file_name.scan(/^(.*)(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})([+-]\d{2,4})\.([a-zA-Z0-9]+)$/) do |prefix, year, month, day, hour, min, sec, offset, extension|
          raw = {prefix: prefix, year: year, month: month, day: day, hour: hour, min: min, sec: sec, offset: offset, ext: extension}
          @logger.debug(get_class_name) { "Raw parse from parse_datetime_offset_filename for #{file_name}: #{raw}." }

          result[:recorded_date] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, offset).iso8601(3)
          result[:prefix] = prefix.blank? ? prefix : prefix.trim('_', '')
          result[:extension] = extension
          result[:utc_offset] = offset
        end
        result
      end

      # Get info from file name with suffix using specified utc offset.
      # @param [String] file_name
      # @param [String] utc_offset
      # @return [Hash] info from file name
      def parse_datetime_suffix_filename(file_name, utc_offset)
        result = {}
        # valid: SERF_20130314_000021_000.wav, a_20130314_000021_a.a, a_99999999_999999_a.dnsb48364JSFDSD
        file_name.scan(/^(.*)(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})_(.*?)\.([a-zA-Z0-9]+)$/) do |prefix, year, month, day, hour, min, sec, suffix, extension|
          raw = {prefix: prefix, year: year, month: month, day: day, hour: hour, min: min, sec: sec, suffix: suffix, ext: extension}
          @logger.debug(get_class_name) { "Raw parse from parse_datetime_suffix_filename for #{file_name}: #{raw}." }

          result[:recorded_date] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset).iso8601(3)
          result[:prefix] = prefix.blank? ? prefix : prefix.trim('_', '')
          result[:suffix] = suffix.blank? ? suffix : suffix.trim('_', '')
          result[:extension] = extension
          result[:utc_offset] = utc_offset
        end
        result
      end

      # Get folder settings.
      # If the config file does not exist, that's ok,
      # some files might have that info in their file names
      # so the settings file might not exist
      # @param [string] folder_settings_file
      # @return [Hash]
      def get_folder_settings(folder_settings_file)

        folder_settings = {}

        if File.exists?(folder_settings_file)
          @logger.debug(get_class_name) {
            "Found folder settings file #{folder_settings_file}."
          }

          # load the config file
          config_file_object = YAML.load_file(folder_settings_file)

          # get project_id and site_id from config file, raise exception if they are not defined
          folder_settings[:project_id] = config_file_object['project_id']
          folder_settings[:site_id] = config_file_object['site_id']
          folder_settings[:uploader_id] = config_file_object['uploader_id']
          folder_settings[:utc_offset] = config_file_object['utc_offset']

          check_folder_settings_value(folder_settings_file, 'project_id', folder_settings[:project_id], lambda { |value| settings_value_numeric?(value) })
          check_folder_settings_value(folder_settings_file, 'site_id', folder_settings[:site_id], lambda { |value| settings_value_numeric?(value) })
          check_folder_settings_value(folder_settings_file, 'uploader_id', folder_settings[:uploader_id], lambda { |value| settings_value_numeric?(value) })
          check_folder_settings_value(folder_settings_file, 'utc_offset', folder_settings[:utc_offset], lambda { |value| settings_value_time_offset?(value) })

          @logger.debug(get_class_name) { "Folder settings: #{folder_settings}." }

        else
          @logger.warn(get_class_name) { "Folder settings file #{folder_settings_file} does not exist." }
        end
        folder_settings
      end

      # Check a settings value.
      # @param [String] folder_settings_file
      # @param [String] name
      # @param [String] value
      # @param [Proc] check
      # @return [void]
      def check_folder_settings_value(folder_settings_file, name, value, check)
        unless check.call(value)
          msg = "Folder settings file #{folder_settings_file} must contain a valid #{name}, '#{value}' is not valid."
          fail Exceptions::HarvesterConfigurationError, msg
        end
      end

      # Check if a settings value is numeric
      # @param [Object] value
      # @return [Boolean]
      def settings_value_numeric?(value)
        !value.nil? && value.is_a?(Fixnum)
      end

      # Check is a settings value is a time offset.
      # @param [string] value
      # @return [Boolean]
      def settings_value_time_offset?(value)
        !value.blank? && (value.start_with?('+') || value.start_with?('-')) && (value[1..-1] =~ /^\d+$/)
      end

    end
  end
end