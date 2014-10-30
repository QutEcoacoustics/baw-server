module BawAudioTools
  class AudioBase

    attr_reader :audio_defaults, :logger, :temp_dir, :timeout_sec,
                :audio_ffmpeg, :audio_mp3splt, :audio_sox,
                :audio_wavpack, :audio_shntool

    public

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
    # @return [BawAudioTools::AudioBase]
    def self.from_executables(audio_defaults, logger, temp_dir, timeout_sec, opts = {})
      audio_tool_opts = {
          ffmpeg: BawAudioTools::AudioFfmpeg.new(opts[:ffmpeg], opts[:ffprobe], logger, temp_dir),
          mp3splt: BawAudioTools::AudioMp3splt.new(opts[:mp3splt], temp_dir),
          sox: BawAudioTools::AudioSox.new(opts[:sox], temp_dir),
          wavpack: BawAudioTools::AudioWavpack.new(opts[:wavpack], temp_dir),
          shntool: BawAudioTools::AudioShntool.new(opts[:shntool], temp_dir)
      }

      run_program = BawAudioTools::RunExternalProgram.new(timeout_sec, logger)

      BawAudioTools::AudioBase.new(audio_defaults, logger, temp_dir, run_program, audio_tool_opts)
    end

    # Construct path to a temp file with extension that does not exist.
    # @return Path to a file. The file does not exist.
    # @param [String] extension
    def temp_file(extension)
      File.join(@temp_dir, ::SecureRandom.hex(7)+'.'+extension.trim('.', '')).to_s
    end

    # Construct path to a temp file with full_name as the file name that does not exist.
    # @return Path to a file. The file does not exist.
    # @param [String] file_name
    def temp_file_from_name(file_name)
      File.join(@temp_dir, file_name).to_s
    end

    # Provides information about an audio file.
    def info(source)
      fail Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      fail Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if File.size(source) < 1

      ffmpeg_info_cmd = @audio_ffmpeg.info_command(source)
      ffmpeg_info_output = @run_program.execute(ffmpeg_info_cmd)

      ffmpeg_info = @audio_ffmpeg.parse_ffprobe_output(source, ffmpeg_info_output)

      @audio_ffmpeg.check_for_errors(ffmpeg_info_output)

      # extract only necessary information into a flattened hash
      info_flattened = {
          media_type: @audio_ffmpeg.get_mime_type(ffmpeg_info),
          sample_rate: ffmpeg_info['STREAM sample_rate'].to_f,
          duration_seconds: @audio_ffmpeg.parse_duration(ffmpeg_info['FORMAT duration']).to_f
      }

      # calculate the bit rate in bits per second (bytes * 8 = bits)
      info_flattened[:bit_rate_bps_calc] = (File.size(source).to_f * 8.0) / info_flattened[:duration_seconds]

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

      if info_flattened[:media_type] == 'audio/wavpack'
        # only get wavpack info for wavpack files
        wavpack_info_cmd = @audio_wavpack.info_command(source)
        wavpack_info_output = @run_program.execute(wavpack_info_cmd)
        wavpack_info = @audio_wavpack.parse_info_output(wavpack_info_output[:stdout])
        wavpack_error = @audio_wavpack.parse_error_output(wavpack_info_output[:stderr])
        @audio_wavpack.check_for_errors(wavpack_info_output)

        info_flattened[:bit_rate_bps] = wavpack_info['ave bitrate'].to_f * 1000.0
        info_flattened[:data_length_bytes] = wavpack_info['file size'].to_f
        info_flattened[:channels] = wavpack_info['channels'].to_i
        info_flattened[:duration_seconds] = @audio_wavpack.parse_duration(wavpack_info['duration']).to_f

        #elsif info_flattened[:media_type] == 'audio/wav'
        #  # only get shntool info for wav files
        #  shntool_info_cmd = @audio_shntool.info_command(source)
        #  shntool_info_output = @run_program.execute(shntool_info_cmd)
        #  shntool_info = @audio_shntool.parse_info_output(shntool_info_output[:stdout])
        #  @audio_shntool.check_for_errors(shntool_info_output)
        #
        #  info_flattened[:bit_rate_bps] = shntool_info['Average bytes/sec'].to_f
        #  info_flattened[:data_length_bytes] = shntool_info['Actual file size'].to_f
        #  info_flattened[:channels] = shntool_info['Channels'].to_i
        #  info_flattened[:duration_seconds] = @audio_shntool.parse_duration(shntool_info['Length']).to_f

      else
        # get ffmpeg info for everything else
        info_flattened[:bit_rate_bps] = ffmpeg_info['STREAM bit_rate'].to_i
        info_flattened[:bit_rate_bps] = ffmpeg_info['FORMAT bit_rate'].to_i if info_flattened[:bit_rate_bps].blank?
        info_flattened[:data_length_bytes] = ffmpeg_info['FORMAT size'].to_i
        info_flattened[:channels] = ffmpeg_info['STREAM channels'].to_i
        # duration
      end

      @logger.debug(@class_name) {
        "Info for #{source}: #{info_flattened.to_json}"
      }

      info_flattened
    end

    def integrity_check(source)
      fail Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source

      if File.extname(source) != '.wv'
        # ffmpeg for everything except wavpack
        ffmpeg_integrity_cmd = @audio_ffmpeg.integrity_command(source)
        ffmpeg_integrity_output = @run_program.execute(ffmpeg_integrity_cmd, false)
        output = @audio_ffmpeg.check_integrity_output(ffmpeg_integrity_output)
      else
        # wavpack for wv files
        wvpack_integrity_cmd = @audio_wavpack.integrity_command(source)
        wvpack_integrity_output = @run_program.execute(wvpack_integrity_cmd, false)
        output = @audio_wavpack.check_integrity_output(wvpack_integrity_output)
      end

      output
    end

    # Creates a new audio file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options for modify_parameters:
    # :start_offset :end_offset :channel :sample_rate :format
    def modify(source, target, modify_parameters = {})
      fail ArgumentError, "Source and Target are the same file: #{target}" if source == target
      fail Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      fail Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target

      source_info = info(source)

      check_offsets(source_info, @audio_defaults.min_duration_seconds, @audio_defaults.max_duration_seconds, modify_parameters)
      check_sample_rate(target, modify_parameters)

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

      if modify_parameters.include? :start_offset
        start_offset = modify_parameters[:start_offset].to_f
      end

      if modify_parameters.include? :end_offset
        end_offset = modify_parameters[:end_offset].to_f
      end

      if end_offset < start_offset
        temp_end_offset = end_offset
        end_offset = start_offset
        start_offset = temp_end_offset
      end

      duration = end_offset - start_offset
      fail Exceptions::SegmentRequestTooLong, "#{end_offset} - #{start_offset} = #{duration} (max: #{max_duration_seconds})" if duration > max_duration_seconds
      fail Exceptions::SegmentRequestTooShort, "#{end_offset} - #{start_offset} = #{duration} (min: #{min_duration_seconds})" if duration < min_duration_seconds

      modify_parameters[:start_offset] = start_offset
      modify_parameters[:end_offset] = end_offset
      modify_parameters[:duration] = duration

      modify_parameters
    end

    def check_target(target)
      fail Exceptions::FileNotFoundError, "#{target}" unless File.exists?(target)
      fail Exceptions::FileEmptyError, "#{target}" if File.size(target) < 1
    end

    def check_sample_rate(target, modify_parameters = {})
      # enforce sample rates for all formats, including wav
      # must be 8, 11.025, 12, 16, 22.05, 24, 32, 44.1, 48 khz
      if modify_parameters.include?(:sample_rate)
        sample_rate = modify_parameters[:sample_rate].to_i
        fail Exceptions::InvalidSampleRateError, "Sample rate #{sample_rate} requested for " +
                                                   "#{File.extname(target)} not in #{AudioBase.valid_sample_rates}." unless AudioBase.valid_sample_rates.include?(sample_rate)
      end
    end

    def self.valid_sample_rates
      [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
    end

    def execute(cmd)
      @run_program.execute(cmd)
    end

    private

    # @param [Hash] source_info
    # @param [string] source
    # @param [string] target
    # @param [Hash] modify_parameters
    def modify_worker(source_info, source, target, modify_parameters = {})
      if source_info[:media_type] == 'audio/wavpack'
        # convert to wave and segment
        audio_tool_segment('wav', :modify_wavpack, source, source_info, target, modify_parameters)
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
      self.send(audio_tool_method, source, source_info, temp_file, modify_parameters[:start_offset], modify_parameters[:end_offset])
      check_target(temp_file)

      # remove start and end offset from new_params (otherwise it will be done again!)
      new_params = {}.merge(modify_parameters)
      new_params.delete :start_offset if new_params.include?(:start_offset)
      new_params.delete :end_offset if  new_params.include?(:end_offset)

      # more processing might be required
      modify_worker(info(temp_file), temp_file, target, new_params)

      File.delete temp_file
    end



  end
end