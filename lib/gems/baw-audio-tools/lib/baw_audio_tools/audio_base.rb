# frozen_string_literal: true

module BawAudioTools
  class AudioBase
    attr_reader :audio_defaults, :logger, :temp_dir, :timeout_sec,
                :audio_ffmpeg, :audio_mp3splt, :audio_sox,
                :audio_wavpack, :audio_shntool, :audio_wav2png,
                :audio_wac2wav

    # @return [BawAudioTools::RunExternalProgram]
    attr_reader :run_program

    # Create a new BawAudioTools::AudioBase.
    # @param [Hash] audio_defaults
    # @param [Logger] logger
    # @param [BawAudioTools::RunExternalProgram] run_program

    # @param [Hash] opts the available audio tools
    # @option opts [BawAudioTools::AudioFfmpeg] :ffmpeg
    # @option opts [BawAudioTools::AudioMp3splt] :mp3splt
    # @option opts [BawAudioTools::AudioSox] :sox
    # @option opts [BawAudioTools::AudioWavpack] :wavpack
    # @option opts [BawAudioTools::AudioShntool] :shntool
    # @option opts [BawAudioTools::AudioWaveform] :wav2png
    # @option opts [BawAudioTools::AudioWac2wav] :wac2wav
    # @return [BawAudioTools::AudioBase]
    def initialize(audio_defaults, logger, temp_dir, run_program, opts = {})
      @audio_defaults = audio_defaults
      @logger = logger
      @temp_dir = temp_dir
      @run_program = run_program

      @audio_ffmpeg = opts[:ffmpeg]
      @audio_mp3splt = opts[:mp3splt]
      @audio_sox = opts[:sox]
      @audio_wavpack = opts[:wavpack]
      @audio_shntool = opts[:shntool]
      @audio_wav2png = opts[:wav2png]
      @audio_wac2wav = opts[:wac2wav]

      @class_name = self.class.name
    end

    # Create a new BawAudioTools::AudioBase.
    # @param [Hash] audio_defaults
    # @param [Logger] logger
    # @param [String] temp_dir
    # @param [Integer] timeout_sec
    # @param [Hash] opts the available audio tools
    # @option opts [String] :ffmpeg path to executable
    # @option opts [String] :ffprobe path to executable
    # @option opts [String] :mp3splt path to executable
    # @option opts [String] :sox path to executable
    # @option opts [String] :wavpack path to executable
    # @option opts [String] :shntool path to executable
    # @option opts [String] :wav2png path to executable
    # @return [BawAudioTools::AudioBase]
    def self.from_executables(audio_defaults, logger, temp_dir, timeout_sec, opts = {})
      audio_tool_opts = {
        ffmpeg: BawAudioTools::AudioFfmpeg.new(opts[:ffmpeg], opts[:ffprobe], logger, temp_dir),
        mp3splt: BawAudioTools::AudioMp3splt.new(opts[:mp3splt], temp_dir),
        sox: BawAudioTools::AudioSox.new(opts[:sox], temp_dir),
        wavpack: BawAudioTools::AudioWavpack.new(opts[:wavpack], temp_dir),
        shntool: BawAudioTools::AudioShntool.new(opts[:shntool], temp_dir),
        wav2png: BawAudioTools::AudioWaveform.new(opts[:wav2png], temp_dir),
        wac2wav: BawAudioTools::AudioWac2wav.new(opts[:wac2wav], temp_dir)
      }

      run_program = BawAudioTools::RunExternalProgram.new(timeout_sec, logger)

      BawAudioTools::AudioBase.new(audio_defaults, logger, temp_dir, run_program, audio_tool_opts)
    end

    # Construct path to a temp file with extension that does not exist.
    # @return Path to a file. The file does not exist.
    # @param [String] extension
    def temp_file(extension)
      File.join(@temp_dir, ::SecureRandom.hex(7) + '.' + extension.trim('.', '')).to_s
    end

    # Construct path to a temp file with full_name as the file name that does not exist.
    # @return Path to a file. The file does not exist.
    # @param [String] file_name
    def temp_file_from_name(file_name)
      File.join(@temp_dir, file_name).to_s
    end

    # Provides information about an audio file.
    def info(source)
      source = check_source(source)

      if File.extname(source) == '.wac'
        info = info_wac2wav(source)
      else
        info = info_ffmpeg(source)
        clipping_check(source, info)
      end

      # calculate the bit rate in bits per second (bytes * 8 = bits)
      info[:bit_rate_bps_calc] = (File.size(source).to_f * 8.0) / info[:duration_seconds]

      if info[:media_type] == 'audio/wavpack'
        # only get wavpack info for wavpack files
        info = info.merge(info_wavpack(source))
        # not using shntool for now, partly because it can't process some .wav formats
        #elsif info[:media_type] == 'audio/wav'
        #  # only get shntool info for wav files
        #  info = info.merge(info_shntool(source))
      end

      @logger.debug(@class_name) do
        "Info for #{source}: #{info.to_json}"
      end

      info
    end

    def info_ffmpeg(source)
      info_cmd = @audio_ffmpeg.info_command(source)
      info_output = @run_program.execute(info_cmd)

      info = @audio_ffmpeg.parse_ffprobe_output(source, info_output)

      stderr = @audio_ffmpeg.check_for_errors(info_output)

      bit_rate_bps = info['STREAM bit_rate']
      bit_rate_bps_format = info['FORMAT bit_rate']
      if bit_rate_bps_format && (bit_rate_bps == '' || bit_rate_bps == 'N/A' || bit_rate_bps == '0')
        bit_rate_bps = bit_rate_bps_format
      end

      {
        media_type: @audio_ffmpeg.get_mime_type(info),
        sample_rate: info['STREAM sample_rate'].to_f,
        duration_seconds: @audio_ffmpeg.parse_duration(info['FORMAT duration']).to_f,
        bit_rate_bps: bit_rate_bps.to_i,
        data_length_bytes: info['FORMAT size'].to_i,
        channels: info['STREAM channels'].to_i
      }
    end

    def info_wavpack(source)
      info_cmd = @audio_wavpack.info_command(source)
      info_output = @run_program.execute(info_cmd)
      info = @audio_wavpack.parse_info_output(info_output[:stdout])
      error = @audio_wavpack.parse_error_output(info_output[:stderr])
      @audio_wavpack.check_for_errors(info_output)

      {
        bit_rate_bps: info['ave bitrate'].to_f * 1000.0,
        data_length_bytes: info['file size'].to_f,
        channels: info['channels'].to_i,
        duration_seconds: @audio_wavpack.parse_duration(info['duration']).to_f
      }
    end

    def info_shntool(source)
      info_cmd = @audio_shntool.info_command(source)
      info_output = @run_program.execute(info_cmd)
      info = @audio_shntool.parse_info_output(info_output[:stdout])
      @audio_shntool.check_for_errors(info_output)

      {
        bit_rate_bps: info['Average bytes/sec'].to_f,
        data_length_bytes: info['Actual file size'].to_f,
        channels: info['Channels'].to_i,
        duration_seconds: @audio_shntool.parse_duration(info['Length']).to_f
      }
    end

    def info_wac2wav(source)
      @audio_wac2wav.info(source)
    end

    def integrity_check(source)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exist? source

      if File.extname(source) == '.wv'
        wvpack_integrity_cmd = @audio_wavpack.integrity_command(source)
        wvpack_integrity_output = @run_program.execute(wvpack_integrity_cmd, false)
        output = @audio_wavpack.check_integrity_output(wvpack_integrity_output)

      elsif File.extname(source) == '.wac'
        # info method checks file header, raises error if not a .wac file
        output = @audio_wac2wav.info(source)

      else
        # ffmpeg for everything else
        ffmpeg_integrity_cmd = @audio_ffmpeg.integrity_command(source)
        ffmpeg_integrity_output = @run_program.execute(ffmpeg_integrity_cmd, false)
        output = @audio_ffmpeg.check_integrity_output(ffmpeg_integrity_output)
      end

      output
    end

    def clipping_check(source, info_flattened)
      # check for clipping, zero signal
      # only if duration less than 4 minutes
      four_minutes_in_sec = 4.0 * 60.0
      if (info_flattened[:media_type] == 'audio/wav' ||
          info_flattened[:media_type] == 'audio/mp3' ||
          info_flattened[:media_type] == 'audio/ogg') &&
         info_flattened[:duration_seconds] < four_minutes_in_sec

        #sox_info_cmd = @audio_sox.info_command_info(source)
        #sox_info_output = @run_program.execute(sox_info_cmd)
        #sox_info = @audio_sox.parse_info_output(sox_info_output[:stdout])

        sox_stat_cmd = @audio_sox.info_command_stat(source)
        sox_stat_output = @run_program.execute(sox_stat_cmd)
        sox_stat = @audio_sox.parse_info_output(sox_stat_output)

        @audio_sox.check_for_errors(sox_stat_output)
        max_amp = sox_stat['Maximum amplitude'].to_f
        info_flattened[:max_amplitude] = max_amp

        # check for audio problems

        # too short
        duration = sox_stat['Length (seconds)'].to_f
        min_useful = 0.5

        if duration < min_useful
          @logger.warn(@class_name) {
            "Audio file duration #{duration} is less than #{min_useful}. This file may not be useful: #{source}"
          }
        end

        # clipped
        min_amp = sox_stat['Minimum amplitude'].to_f
        min_amp_threshold = -0.999
        max_amp_threshold = 0.999

        if min_amp_threshold >= min_amp && max_amp_threshold <= max_amp
          @logger.warn(@class_name) {
            "Audio file has been clipped #{min_amp} (max amplitude #{max_amp_threshold}, min amplitude #{min_amp_threshold}): #{source}"
          }
        end

        # dc offset TODO

        # zero signal
        mean_norm = sox_stat['Mean    norm'].to_f
        zero_sig_threshold = 0.001

        if zero_sig_threshold >= mean_norm
          @logger.warn(@class_name) {
            "Audio file has zero signal #{mean_norm} (mean norm is less than #{zero_sig_threshold}): #{source}"
          }
        end

      end
    end

    # Creates a new audio file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options for modify_parameters:
    # :start_offset :end_offset :channel :sample_rate
    def modify(source, target, modify_parameters = {})
      raise ArgumentError, "Source and Target are the same file: #{target}" if source == target
      source = check_source(source)
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exist? target
      raise Exceptions::InvalidTargetMediaTypeError, 'Cannot convert to .wac' if File.extname(target) == '.wac'

      target = target.to_s if target.is_a?(Pathname)

      source_info = info(source)

      check_offsets(source_info, @audio_defaults.min_duration_seconds, @audio_defaults.max_duration_seconds, modify_parameters)
      check_sample_rate(target, modify_parameters, source_info)

      modify_worker(source_info, source, target, modify_parameters)
    end

    def tempfile_content(tempfile)
      tempfile.rewind
      content = tempfile.read
      tempfile.close
      tempfile.unlink # deletes the temp file
      content
    end

    def check_offsets(source_info, min_duration_seconds, max_duration_seconds, modify_parameters = {})
      start_offset = 0.0
      end_offset = source_info[:duration_seconds].to_f

      start_offset = modify_parameters[:start_offset].to_f if modify_parameters.include? :start_offset

      end_offset = modify_parameters[:end_offset].to_f if modify_parameters.include? :end_offset

      if end_offset < start_offset
        temp_end_offset = end_offset
        end_offset = start_offset
        start_offset = temp_end_offset
      end

      duration = end_offset - start_offset
      if duration > max_duration_seconds
        raise Exceptions::SegmentRequestTooLong, "#{end_offset} - #{start_offset} = #{duration} (max: #{max_duration_seconds})"
      end
      if duration < min_duration_seconds
        raise Exceptions::SegmentRequestTooShort, "#{end_offset} - #{start_offset} = #{duration} (min: #{min_duration_seconds})"
      end

      modify_parameters[:start_offset] = start_offset
      modify_parameters[:end_offset] = end_offset
      modify_parameters[:duration] = duration

      modify_parameters
    end

    def check_target(target)
      raise Exceptions::FileNotFoundError, target.to_s unless File.exist?(target)

      return unless File.size(target) < 1

      # Force open file to invalidate cache. This happens on nfs/cifs caches
      # where it caches metadata
      IO.new(IO.sysopen(target, 'r')).close

      raise Exceptions::FileEmptyError, target.to_s if File.size(target) < 1
    end

    # Checks whether the sample rate in modify_parameters is allowed
    # @param [String] target  the path to the target file (used to determine format and for error reporting)
    # @param [Hash] modify_parameters values specifying how to modify the audio file, including :sample_rate and optionally :original_sample_rate
    # @param [Array] source_info (optional) the metadata of the source file
    # Checks the sample rate specified is in the list of standard sample rates, plus the sample rate of the original file,
    # minus sample rates not supported by the format.
    # Original file sample rate is determined either from the modify_parameters hash (originally coming from the audio recording record)
    # or the source_info hash. If both are supplied, they must be the same value or an exception is thrown    #
    def check_sample_rate(target, modify_parameters = {}, source_info = {})
      if modify_parameters.include?(:sample_rate)
        sample_rate = modify_parameters[:sample_rate].to_i

        # source_info sample_rate_hertz should match modify_parameters original_sample_rate if both are supplied
        if source_info.include?(:sample_rate) &&
           modify_parameters.key?(:original_sample_rate) &&
           source_info[:sample_rate].to_i != modify_parameters[:original_sample_rate].to_i
          raise Exceptions::InvalidSampleRateError, "Sample rate of audio file #{source_info[:sample_rate]} " \
                                                   "not equal to given original sample rate #{modify_parameters[:original_sample_rate]}"
        end

        original_sample_rate = if source_info.include?(:sample_rate)
                                 source_info[:sample_rate].to_i
                               elsif modify_parameters.key?(:original_sample_rate)
                                 modify_parameters[:original_sample_rate]
                               end

        format = File.extname(target)
        format[0] = '' #remove dot character from extension

        valid_sample_rates = AudioBase.valid_sample_rates(format, original_sample_rate)

        unless valid_sample_rates.include?(sample_rate)
          raise Exceptions::InvalidSampleRateError, "Sample rate #{sample_rate} requested for " \
                                                   "#{format} not in #{valid_sample_rates}"
        end

      end
    end

    # returns a list of valid target sample rates for the given target format and source sample rate
    # @param [symbol] format optional if omitted will just give the standard sample rates
    # @param [int] source_sample_rate optional the sample rate to dynamically include in the valid sample rates
    def self.valid_sample_rates(format = nil, source_sample_rate = nil)
      formats_valid_sample_rates = {
        mp3: [8000, 12_000, 11_025, 16_000, 24_000, 22_050, 32_000, 48_000, 44_100]
      }

      sample_rates = AudioBase.standard_sample_rates
      sample_rates.push(source_sample_rate.to_i) if source_sample_rate && !sample_rates.include?(source_sample_rate)

      # if the target format is in the hash of whitelisted sample rates,
      # intersect those target format valid sample rates with the standard sample rates
      if format && formats_valid_sample_rates.key?(format.to_sym)
        sample_rates &= formats_valid_sample_rates[format.to_sym]
      end

      sample_rates
    end

    # a list of standard sample rates, defined so that the number of possible
    # cached files is reduced
    def self.standard_sample_rates
      [8000, 11_025, 12_000, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000, 96_000]
    end

    def execute(cmd)
      @run_program.execute(cmd)
    end

    private

    # Check if a source exists, and is a file.
    # @return [Pathname] the real path of the given path.
    def check_source(path)
      raise Exceptions::FileNotFoundError, 'Source path was empty or nil' if path.nil? || (path.is_a?(String) && path.empty?)
      path = Pathname(path)

      # Maybe worth resolving symlinks to a realpath, but currently does not cause any failures without
      #path = File.realpath(File.readlink(path)) if File.symlink?(path)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{path}" unless path.exist?
      raise Exceptions::FileEmptyError, "Source exists, but has no content: #{path}" if path.zero?

      path
    end

    # @param [Hash] source_info
    # @param [string] source
    # @param [string] target
    # @param [Hash] modify_parameters
    def modify_worker(source_info, source, target, modify_parameters = {})
      if source_info[:media_type] == 'audio/wavpack'
        # convert to wave and segment
        audio_tool_segment('wav', :modify_wavpack, source, source_info, target, modify_parameters)
      elsif source_info[:media_type] == 'audio/x-waac'
        # convert .wac to .wav
        modify_wac2wav(source, target, modify_parameters)

      elsif source_info[:media_type] == 'audio/mp3' && (modify_parameters.include?(:start_offset) || modify_parameters.include?(:end_offset))
        # segment only, so check for offsets
        audio_tool_segment('mp3', :modify_mp3splt, source, source_info, target, modify_parameters)
        #elsif source_info[:media_type] == ' audio/wav ' && (modify_parameters.include?(:start_offset) || modify_parameters.include?(:end_offset))
        #  # segment only, so check for offsets
        #  audio_tool_segment(' wav ', :modify_shntool, source, source_info, target, modify_parameters)
      else

        start_offset = modify_parameters.include?(:start_offset) ? modify_parameters[:start_offset] : nil
        end_offset = modify_parameters.include?(:end_offset) ? modify_parameters[:end_offset] : nil
        channel = modify_parameters.include?(:channel) ? modify_parameters[:channel] : nil
        sample_rate = modify_parameters.include?(:sample_rate) ? modify_parameters[:sample_rate] : nil

        if modify_parameters.include?(:sample_rate)

          # Convert to wav first to avoid problems with other formats
          temp_file_1 = temp_file('wav')
          cmd = @audio_ffmpeg.modify_command(source, source_info, temp_file_1, start_offset, end_offset)
          @run_program.execute(cmd)
          check_target(temp_file_1)

          # resample using sox.
          temp_file_2 = temp_file('wav')
          cmd = @audio_sox.modify_command(temp_file_1, info(temp_file_1), temp_file_2, nil, nil, channel, sample_rate)
          @run_program.execute(cmd)
          check_target(temp_file_2)

          # convert to requested format after resampling
          cmd = @audio_ffmpeg.modify_command(temp_file_2, info(temp_file_2), target)
          @run_program.execute(cmd)
          check_target(temp_file_1)

          File.delete temp_file_1
          File.delete temp_file_2
        else
          # use ffmpeg for anything else
          cmd = @audio_ffmpeg.modify_command(source, source_info, target, start_offset, end_offset, channel, sample_rate)
          @run_program.execute(cmd)
          check_target(target)
        end

      end
    end

    def modify_wavpack(source, source_info, target, start_offset, end_offset)
      cmd = @audio_wavpack.modify_command(source, source_info, target, start_offset, end_offset)
      @run_program.execute(cmd)
    end

    def modify_mp3splt(source, source_info, target, start_offset, end_offset)
      cmd = @audio_mp3splt.modify_command(source, source_info, target, start_offset, end_offset)
      @run_program.execute(cmd)
    end

    def modify_wac2wav(source, target, modify_parameters)
      # process the source file, put output to temp file
      temp_file = temp_file('wav')

      cmd = @audio_wac2wav.modify_command(source, temp_file)
      @run_program.execute(cmd)

      check_target(temp_file)

      # more processing might be required
      modify_worker(info(temp_file), temp_file, target, modify_parameters)

      File.delete temp_file
    end

    #def modify_shntool(source, source_info, target, start_offset, end_offset)
    #  cmd = @audio_shntool.modify_command(source, source_info, target, start_offset, end_offset)
    #  @run_program.execute(cmd)
    #end

    # @param [string] extension
    # @param [Symbol] audio_tool_method
    # @param [string] source
    # @param [Hash] source_info
    # @param [string] target
    # @param [Hash] modify_parameters
    def audio_tool_segment(extension, audio_tool_method, source, source_info, target, modify_parameters)
      # process the source file, put output to temp file
      temp_file = temp_file(extension)
      send(audio_tool_method, source, source_info, temp_file, modify_parameters[:start_offset], modify_parameters[:end_offset])
      check_target(temp_file)

      # remove start and end offset from new_params (otherwise it will be done again!)
      new_params = {}.merge(modify_parameters)
      new_params.delete :start_offset if new_params.include?(:start_offset)
      new_params.delete :end_offset if new_params.include?(:end_offset)

      # more processing might be required
      modify_worker(info(temp_file), temp_file, target, new_params)

      File.delete temp_file
    end
  end
end
