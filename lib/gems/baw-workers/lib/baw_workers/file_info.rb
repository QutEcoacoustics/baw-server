# frozen_string_literal: true

module BawWorkers
  # Helpers to get info from files.
  class FileInfo
    def initialize(audio_base)
      @audio = audio_base
    end

    # Get info for an existing file.
    # @param [String] source
    # @return [Hash] information about an existing file
    def audio_info(source)
      # based on how harvester gets file hash.
      generated_file_hash = "SHA256::#{generate_hash(source).hexdigest}"

      # integrity
      integrity_check = @audio.integrity_check(source)

      # get file info using ffmpeg
      info = @audio.info(source)

      {
        file: source,
        extension: File.extname(source).delete('.'),
        errors: integrity_check[:errors],
        file_hash: generated_file_hash,
        media_type: info[:media_type],
        sample_rate_hertz: info[:sample_rate],
        duration_seconds: info[:duration_seconds].to_f.round(3),
        bit_rate_bps: info[:bit_rate_bps],
        data_length_bytes: info[:data_length_bytes],
        channels: info[:channels]
      }
    end

    # @param [string] source
    # @return [Digest::SHA256] Digest::SHA256 of file
    def generate_hash(source)
      incr_hash = Digest::SHA256.new

      File.open(source) do |file|
        buffer = String.new

        # Read the file 512 bytes at a time
        until file.eof
          file.read(512, buffer)
          incr_hash.update(buffer)
        end
      end

      incr_hash
    end

    # Copy one source file to many destinations.
    # @param [String] source
    # @param [Array<String>] targets
    # @return [void]
    def copy_to_many(source, targets)
      expanded_source = File.expand_path(source)

      targets.each do |target|
        expanded_target = File.expand_path(target)

        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(expanded_target))

        # copy file to other locations
        FileUtils.cp(expanded_source, expanded_target)
      end
    end

    # Get basic file info.
    # @param [string] source
    # @return [Hash]
    def basic(source)
      {
        file_path: File.expand_path(source),
        file_name: File.basename(source),
        extension: File.extname(source).reverse.chomp('.').reverse,
        access_time: File.atime(source),
        change_time: File.ctime(source),
        modified_time: File.mtime(source),
        data_length_bytes: File.size(source)
      }
    end

    # Get advanced file info.
    # @param [String] source
    # @param [String] utc_offset
    # @return [Hash] file properties
    def advanced(source, utc_offset = nil)
      file_name = File.basename(source)

      info = file_name_all(file_name)
      info = file_name_datetime(file_name, utc_offset) if info.empty?

      info
    end

    # Check that this file's extension is valid.
    # @param [String] file
    # @param [Array<String>] ext_include
    # @param [Array<String>] ext_exclude
    # @return [Boolean] valid extension
    def valid_ext?(file, ext_include, ext_exclude = nil)
      ext = File.extname(file).trim('.', '').downcase

      is_excluded_ext = false
      is_excluded_ext = ext_exclude.include?(ext) unless ext_exclude.blank?

      ext_include.include?(ext) && !is_excluded_ext
    end

    # Check if a settings value is numeric
    # @param [Object] value
    # @return [Boolean]
    def numeric?(value)
      !value.nil? && value.is_a?(Integer)
    end

    def booleric?(value)
      [true, false].include?(value)
    end

    # Check is a settings value is a time offset.
    # @example
    #      '+1000'
    # @param [string] value
    # @return [Boolean]
    def time_offset?(value)
      !value.blank? && ((value =~ /^(\+|-)\d{1,2}(:?\d{2})?$/) != nil)
    end

    # Get info from upload dir file name.
    # @param [String] file_name
    # @return [Hash] info from file name
    def file_name_all(file_name)
      result = {}
      regex = /^p(\d+)_s(\d+)_u(\d+)_d(\d{4})(\d{2})(\d{2})_t(\d{2})(\d{2})(\d{2})Z\.([a-zA-Z0-9]+)$/
      file_name.scan(regex) do |project_id, site_id, uploader_id, year, month, day, hour, min, sec, extension|
        result[:raw] = {
          project_id: project_id, site_id: site_id, uploader_id: uploader_id,
          year: year, month: month, day: day,
          hour: hour, min: min, sec: sec,
          offset: 'Z', ext: extension
        }

        result[:project_id] = project_id.to_i
        result[:site_id] = site_id.to_i
        result[:uploader_id] = uploader_id.to_i

        result[:utc_offset] = 'Z'
        result[:recorded_date] =
          DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, 'Z').iso8601(3)
        result[:prefix] = ''
        result[:separator] = '_'
        result[:suffix] = ''
        result[:extension] = extension.blank? ? '' : extension
      end
      result
    end

    # Get info from file name using specified utc offset.
    # @param [String] file_name
    # @param [String] utc_offset
    # @return [Hash] info from file name
    def file_name_datetime(file_name, utc_offset = nil)
      result = {}
      regex = /^(.*)(\d{4})(\d{2})(\d{2})(-|_|T)?(\d{2})(\d{2})(\d{2})([+\-]\d{4}|[+\-]\d{1,2}:\d{2}|[+\-]\d{1,2}|Z)?(.*)\.([a-zA-Z0-9]+)$/
      file_name.scan(regex) do |prefix, year, month, day, separator, hour, minute, second, offset, suffix, extension|
        result[:raw] = {
          year: year, month: month, day: day,
          hour: hour, min: minute, sec: second,
          offset: offset.blank? ? '' : offset,
          ext: extension
        }
        available_offset = offset || utc_offset
        if available_offset.blank?
          raise BawWorkers::Exceptions::HarvesterConfigurationError,
                'No UTC offset provided and file name did not contain a utc offset.'
        end

        result[:utc_offset] = available_offset
        result[:recorded_date] =
          DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_i,
                       result[:utc_offset]).iso8601(3)
        result[:prefix] = prefix.blank? ? '' : prefix
        result[:separator] = separator.blank? ? '' : separator
        result[:suffix] = suffix.blank? ? '' : suffix
        result[:extension] = extension.blank? ? '' : extension
      end
      result
    end
  end
end
