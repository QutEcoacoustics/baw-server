# frozen_string_literal: true

module BawWorkers
  # Helpers to get info from files.
  class FileInfo
    # Note a leading plus or minus is required!
    UTC_OFFSET_REGEX = /^(\+|-)\d{1,2}(:?\d{2})?$/

    def initialize(audio_base)
      @audio = audio_base
    end

    # Get info for an existing file.
    # @param [String] source
    # @return [Hash] information about an existing file
    def audio_info(source, file_info)
      if file_info[:file_hash].blank?
        # based on how harvester gets file hash.
        generated_file_hash = "SHA256::#{generate_hash(source).hexdigest}"
        file_info[:file_hash] = generated_file_hash
      end

      # integrity
      integrity_check = @audio.integrity_check(source)
      file_info[:errors] = integrity_check[:errors]

      file_info[:extension] = File.extname(source).delete('.') if file_info[:extension].blank?

      [:media_type, :sample_rate_hertz, :duration_seconds, :bit_rate_bps, :data_length_bytes, :channels].any? do |key|
        file_info[key].blank?
      end => need_to_run_ffmpeg

      if need_to_run_ffmpeg
        # get file info using ffmpeg
        info = @audio.info(source)

        file_info = file_info.merge({
          media_type: info[:media_type],
          sample_rate_hertz: info[:sample_rate].to_i,
          duration_seconds: info[:duration_seconds].to_f.round(3),
          bit_rate_bps: info[:bit_rate_bps],
          data_length_bytes: info[:data_length_bytes],
          channels: info[:channels]
        })
      end

      file_info
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

    # copy a source file to a destination.
    # The first successful copy to a target will be used.
    # Will try subsequent targets if the first fails.
    # @param [Pathname] source
    # @param [Array<Pathname>] targets
    # @return [Pathname] the first successful target
    def copy_to_any(source, targets)
      raise "File not found: #{source}" unless source.exist?
      raise 'No targets provided' if targets.empty?

      # try each target
      targets.each do |target|
        raise "Target is not a Pathname: #{target}" unless target.is_a?(Pathname)

        target.dirname.mkpath

        FileUtils.copy(source, target)

        exist = target.exist?
        size = target.size
        unless exist && size == source.size
          raise "Failed to copy #{source} to #{target}, exists?:#{exist}, size:#{size}, source_size:#{source.size}"
        end

        return target
      rescue StandardError => e
        BawWorkers::Config.logger_worker.warn "Failed to move #{source} to #{target}: #{e}"
      end

      # if we get here, all targets failed
      raise "Failed to move #{source} to any of #{targets}"
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
    def advanced(source, file_info, utc_offset = nil, throw: true)
      file_name = File.basename(source)

      # so we always want to parse this date format because it is special to our website
      info = file_name_all(file_name)

      if info.empty?
        # if we already have a recorded_date we don't need to do this again
        return file_info if file_info[:recorded_date].present?

        file_info.merge(file_name_datetime(file_name, utc_offset, throw:))
      else
        file_info.merge(info)
      end
    end

    # Check that this file's extension is valid.
    # @param [String] file
    # @param [Array<String>] ext_include
    # @param [Array<String>] ext_exclude
    # @return [Boolean] valid extension
    def valid_ext?(file, ext_include, ext_exclude = nil)
      ext = File.extname(file).trim('.', '').downcase

      is_excluded_ext = false
      is_excluded_ext = ext_exclude.include?(ext) if ext_exclude.present?

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
      value.present? && value =~ UTC_OFFSET_REGEX
    end

    # Get info from upload dir file name.
    # @param [String] file_name
    # @return [Hash] info from file name
    def file_name_all(file_name)
      result = {}
      regex = /^p(\d+)_s(\d+)_u(\d+)_d(\d{4})(\d{2})(\d{2})_t(\d{2})(\d{2})(\d{2})Z\.([a-zA-Z0-9]+)$/
      file_name.scan(regex) do |project_id, site_id, uploader_id, year, month, day, hour, min, sec, extension|
        result[:raw] = {
          project_id:, site_id:, uploader_id:,
          year:, month:, day:,
          hour:, min:, sec:,
          offset: 'Z', ext: extension
        }

        result[:project_id] = project_id.to_i
        result[:site_id] = site_id.to_i
        result[:uploader_id] = uploader_id.to_i

        result[:utc_offset] = 'Z'
        result[:recorded_date_local] =
          Time.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, nil).iso8601(3)
        result[:recorded_date] =
          Time.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, 'Z').iso8601(3)
        result[:prefix] = ''
        result[:separator] = '_'
        result[:suffix] = ''
        result[:extension] = (extension.presence || '')
      end
      result
    end

    # Get info from file name using specified utc offset.
    # @param [String] file_name
    # @param [String] utc_offset
    # @return [Hash] info from file name
    def file_name_datetime(file_name, utc_offset = nil, throw: true)
      result = {}
      regex = /^(.*?)(\d{4})(\d{2})(\d{2})(-|_|T|\$)?(\d{2})(\d{2})(\d{2})(\.?\d{1,9})?([+\-]\d{4}|[+\-]\d{1,2}:\d{2}|[+\-]\d{1,2}|Z)?(.*)\.([a-zA-Z0-9]+)$/
      file_name.scan(regex) do |prefix, year, month, day, separator, hour, minute, second, factional, offset, suffix, extension|
        has_factional = factional.present?
        factional = has_factional ? factional&.ltrim('.') : ''
        precision = has_factional ? factional.length : 0
        second += has_factional ? ".#{factional}" : ''
        offset = offset.then { |o|
          case o
          in 'Z'
            'Z'
          in /^[+\-]\d{1,2}:\d{2}$/
            o
          in /^[+\-]\d{1,2}$/
            "#{o}:00"
          in /^[+\-]\d{4}$/
            o.insert(3, ':')
          else
            ''
          end
        }

        result[:raw] = {
          year:, month:, day:,
          hour:, min: minute, sec: second,
          offset:,
          ext: extension
        }

        available_offset = offset.presence || utc_offset
        if available_offset.blank? && throw
          raise BawWorkers::Exceptions::HarvesterConfigurationError,
            'No UTC offset provided and file name did not contain a utc offset.'
        end

        result[:utc_offset] = available_offset

        # ruby doesn't really support local times, so we're parsing this but immediately converting back to
        # a string without the offset to ensure we don't pass around invalid Time instances (
        # if we did keep it has a time, it would have utc_offset of 0)
        result[:recorded_date_local] = Time
          .new(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_r, nil)
          .iso8601(precision).slice(0..-7)

        if available_offset.blank?
          nil
        else
          Time.new(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_r, result[:utc_offset])
        end => recorded_date
        result[:recorded_date] = recorded_date

        result[:prefix] = (prefix.presence || '')
        result[:separator] = (separator.presence || '')
        result[:suffix] = (suffix.presence || '')
        result[:extension] = (extension.presence || '')
      end
      result
    end
  end
end
