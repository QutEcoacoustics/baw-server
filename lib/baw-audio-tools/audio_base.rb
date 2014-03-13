require 'open3'

module BawAudioTools
  class AudioBase

    attr_reader :audio_ffmpeg, :audio_mp3splt, :audio_sox, :audio_wavpack, :temp_dir, :audio_defaults

    public

    def initialize(audio_ffmpeg, audio_mp3splt, audio_sox, audio_wavpack, audio_defaults, temp_dir)
      @audio_ffmpeg = audio_ffmpeg
      @audio_mp3splt = audio_mp3splt
      @audio_sox = audio_sox
      @audio_wavpack =audio_wavpack
      @audio_defaults = audio_defaults
      @temp_dir = temp_dir
    end

    def self.from_executables(ffmpeg_executable, ffprobe_executable,
        mp3splt_executable, sox_executable, wavpack_executable,
        audio_defaults, temp_dir)
      audio_ffmpeg = BawAudioTools::AudioFfmpeg.new(ffmpeg_executable, ffprobe_executable, temp_dir)
      audio_mp3splt = BawAudioTools::AudioMp3splt.new(mp3splt_executable, temp_dir)
      audio_sox = BawAudioTools::AudioSox.new(sox_executable, temp_dir)
      audio_wavpack = BawAudioTools::AudioWavpack.new(wavpack_executable, temp_dir)
      #audio_shntool = AudioShntool.new(shntool_executable, temp_dir)

      BawAudioTools::AudioBase.new(audio_ffmpeg, audio_mp3splt, audio_sox, audio_wavpack, audio_defaults, temp_dir)
    end

    # @return Path to a file. The file does not exist.
    def temp_file(extension)
      File.join(@temp_dir, ::SecureRandom.hex(7)+'.'+extension.trim('.', '')).to_s
    end

    # Provides information about an audio file.
    def info(source)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if File.size(source) < 1

      ffmpeg_info_cmd = @audio_ffmpeg.info_command(source)
      ffmpeg_info_output = execute(ffmpeg_info_cmd)
      ffmpeg_info = @audio_ffmpeg.parse_ffprobe_output(source, ffmpeg_info_output[:stdout])

      @audio_ffmpeg.check_for_errors(ffmpeg_info_output[:stdout], ffmpeg_info_output[:stderr])

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
        #sox_info_output = execute(sox_info_cmd)
        #sox_info = @audio_sox.parse_info_output(sox_info_output[:stdout])

        sox_stat_cmd = @audio_sox.info_command_stat(source)
        sox_stat_output = execute(sox_stat_cmd)
        sox_stat = @audio_sox.parse_info_output(sox_stat_output[:stderr])

        @audio_sox.check_for_errors(sox_stat_output[:stdout], sox_stat_output[:stderr])
        max_amp = sox_stat['Maximum amplitude'].to_f
        info_flattened[:max_amplitude] = max_amp

        # check for audio problems

        # too short
        duration = sox_stat['Length (seconds)'].to_f
        min_useful = 0.5
        Logging::logger.warn "Audio file duration #{duration} is less than #{min_useful}. This file may not be useful: #{source}" if duration < min_useful

        # clipped
        min_amp = sox_stat['Minimum amplitude'].to_f
        min_amp_threshold = -0.999
        max_amp_threshold = 0.999
        Logging::logger.warn "Audio file has been clipped #{min_amp} (max amplitude #{max_amp_threshold}, min amplitude #{min_amp_threshold}): #{source}" if min_amp_threshold >= min_amp && max_amp_threshold <= max_amp

        # dc offset TODO

        # zero signal
        mean_norm = sox_stat['Mean    norm'].to_f
        zero_sig_threshold = 0.001
        Logging::logger.warn "Audio file has zero signal #{mean_norm} (mean norm is less than #{zero_sig_threshold}): #{source}" if zero_sig_threshold >= mean_norm

      end

      if info_flattened[:media_type] == 'audio/wavpack'
        # only get wavpack info for wavpack files
        wavpack_info_cmd = @audio_wavpack.info_command(source)
        wavpack_info_output = execute(wavpack_info_cmd)
        wavpack_info = @audio_wavpack.parse_info_output(wavpack_info_output[:stdout])
        wavpack_error = @audio_wavpack.parse_error_output(wavpack_info_output[:stderr])
        @audio_wavpack.check_for_errors(wavpack_info_output[:stdout], wavpack_info_output[:stderr])

        info_flattened[:bit_rate_bps] = wavpack_info['ave bitrate'].to_f * 1000.0
        info_flattened[:data_length_bytes] = wavpack_info['file size'].to_f
        info_flattened[:channels] = wavpack_info['channels'].to_i
        info_flattened[:duration_seconds] = @audio_wavpack.parse_duration(wavpack_info['duration']).to_f

        #elsif info_flattened[:media_type] == 'audio/wav'
        #  # only get shntool info for wav files
        #  shntool_info_cmd = @audio_shntool.info_command(source)
        #  shntool_info_output = execute(shntool_info_cmd)
        #  shntool_info = @audio_shntool.parse_info_output(shntool_info_output[:stdout])
        #  @audio_shntool.check_for_errors(shntool_info_output[:stdout], shntool_info_output[:stderr])
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

      Logging::logger.debug "Info for #{source}: #{info_flattened.to_json}"

      info_flattened
    end

    # Creates a new audio file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options for modify_parameters:
    # :start_offset :end_offset :channel :sample_rate :format
    def modify(source, target, modify_parameters = {})
      raise ArgumentError, "Source and Target are the same file: #{target}" unless source != target
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target

      source_info = info(source)

      check_offsets(source_info, @audio_defaults.min_duration_seconds, @audio_defaults.max_duration_seconds, modify_parameters)
      check_sample_rate(target, modify_parameters)

      modify_worker(source_info, source, target, modify_parameters)
    end

    def execute(command)

      if OS.windows?
        #if command.include? '&& move'
        # if windows and contains a 'move' command, need to ensure relative path has '\' separators
        command = command.gsub('/', '\\')
        #else
        #command = command.gsub('\\', '/')
        #end
      end

      stdout_str = ''
      stderr_str = ''
      status = nil
      timed_out = nil
      killed = nil

      time = Benchmark.realtime do
        begin
          run_with_timeout(command, timeout: Settings.audio_tools_timeout_sec) do |output, error, thread, timed_out_return, killed_return|
            #thread_success = thread.value.success?
            stdout_str = output
            stderr_str = error
            status = thread.value
            timed_out = timed_out_return
            killed = killed_return
          end
        rescue Exception => e
          Logging::logger.fatal e
          raise e
        end
      end

      msg = "External Program: status=#{status.exitstatus};time_out_sec=#{Settings.audio_tools_timeout_sec};time_taken_sec=#{time};timed_out=#{timed_out};killed=#{killed};command=#{command}"
      extra_msg = "\n\t Standard output: #{stdout_str}\n\t Standard Error: #{stderr_str}"

      if (!stderr_str.blank? && !status.success?) || timed_out || killed
        Logging::logger.warn msg+extra_msg
      else
        Logging::logger.debug msg+extra_msg
      end

      raise Exceptions::AudioToolTimedOutError, msg + extra_msg if timed_out || killed
      raise Exceptions::AudioToolError, msg + extra_msg if !stderr_str.blank? && !status.success?

      {
          command: command,
          stdout: stdout_str,
          stderr: stderr_str,
          time_taken: time
      }
    end

    def tempfile_content(tempfile)
      tempfile.rewind
      content = tempfile.read
      tempfile.close
      tempfile.unlink # deletes the temp file
      content
    end

    def check_offsets(source_info, min_duration_seconds, max_duration_seconds, modify_parameters = {})
      log_options(modify_parameters, '#check_offsets method start')
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
      raise Exceptions::SegmentRequestTooLong, "#{end_offset} - #{start_offset} = #{duration} (max: #{max_duration_seconds})" if duration > max_duration_seconds
      raise Exceptions::SegmentRequestTooShort, "#{end_offset} - #{start_offset} = #{duration} (min: #{min_duration_seconds})" if duration < min_duration_seconds

      modify_parameters[:start_offset] = start_offset
      modify_parameters[:end_offset] = end_offset
      modify_parameters[:duration] = duration

      log_options(modify_parameters, '#check_offsets method end')

      modify_parameters
    end

    def check_target(target)
      raise Exceptions::FileNotFoundError, "#{target}" unless File.exists?(target)
      raise Exceptions::FileEmptyError, "#{target}" if File.size(target) < 1
    end

    def check_sample_rate(target, modify_parameters = {})
      # must be 8, 11.025, 12, 16, 22.05, 24, 32, 44.1, 48 khz if not wav
      if modify_parameters.include?(:sample_rate) && File.extname(target) != '.wav'
        sample_rate = modify_parameters[:sample_rate].to_i
        valid_sample_rates = [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
        raise Exceptions::InvalidSampleRateError, ' Arbitrary sample rates only valid for wav files. '+
            "Sample rate #{sample_rate} requested for #{File.extname(target)} not in #{valid_sample_rates}." unless valid_sample_rates.include?(sample_rate)
      end
    end

    private

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
          execute(cmd)
          check_target(temp_file_1)

          # resample using sox.
          temp_file_2 = temp_file('wav')
          cmd = @audio_sox.modify_command(temp_file_1, info(temp_file_1), temp_file_2, nil, nil, channel, sample_rate)
          execute(cmd)
          check_target(temp_file_2)

          # convert to requested format after resampling
          cmd = @audio_ffmpeg.modify_command(temp_file_2, info(temp_file_2), target)
          execute(cmd)
          check_target(temp_file_1)

          File.delete temp_file_1
          File.delete temp_file_2
        else
          # use ffmpeg for anything else
          cmd = @audio_ffmpeg.modify_command(source, source_info, target, start_offset, end_offset, channel, sample_rate)
          execute(cmd)
          check_target(target)
        end

      end
    end

    def modify_wavpack(source, source_info, target, start_offset, end_offset)
      cmd = @audio_wavpack.modify_command(source, source_info, target, start_offset, end_offset)
      execute(cmd)
    end

    def modify_mp3splt(source, source_info, target, start_offset, end_offset)
      cmd = @audio_mp3splt.modify_command(source, source_info, target, start_offset, end_offset)
      execute(cmd)
    end

    #def modify_shntool(source, source_info, target, start_offset, end_offset)
    #  cmd = @audio_shntool.modify_command(source, source_info, target, start_offset, end_offset)
    #  execute(cmd)
    #end

    def audio_tool_segment(extension, audio_tool_method, source, source_info, target, modify_parameters)
      # process the source file, put output to temp file
      temp_file = temp_file(extension)
      self.send(audio_tool_method, source, source_info, temp_file, modify_parameters[:start_offset], modify_parameters[:end_offset])
      check_target(temp_file)

      # remove start and end offset from modify_parameters (otherwise it will be done again!)
      modify_parameters.delete :start_offset if modify_parameters.include?(:start_offset)
      modify_parameters.delete :end_offset if  modify_parameters.include?(:end_offset)

      # more processing might be required
      modify_worker(info(temp_file), temp_file, target, modify_parameters)

      File.delete temp_file
    end


    # https://gist.github.com/mgarrick/3108185
    # Runs a specified shell command in a separate thread.
    # If it exceeds the given timeout in seconds, kills it.
    # Passes stdout, stderr, thread, and a boolean indicating a timeout occurred to the passed in block.
    # Uses Kernel.select to wait up to the tick length (in seconds) between
    # checks on the command's status
    #
    # If you've got a cleaner way of doing this, I'd be interested to see it.
    # If you think you can do it with Ruby's Timeout module, think again.
    def run_with_timeout(*command)
      options = command.extract_options!.reverse_merge(timeout: 60, tick: 1, cleanup_sleep: 0.1, buffer_size: 10240)

      timeout = options[:timeout]
      cleanup_sleep = options[:cleanup_sleep]
      tick = options[:tick]
      buffer_size = options[:buffer_size]

      output = ''
      error = ''

      # Start task in another thread, which spawns a process
      Open3.popen3(*command) do |stdin, stdout, stderr, thread|
        # Get the pid of the spawned process
        pid = thread[:pid]
        start = Time.now

        time_remaining = nil
        while (time_remaining = (Time.now - start) < timeout) and thread.alive?
          # Wait up to `tick` seconds for output/error data
          readables, writeables, = Kernel.select([stdout, stderr], nil, nil, tick)
          next if readables.blank?
          readables.each do |readable|
            stream = readable == stdout ? output : error
            begin
              # can't use read_nonblock with pipes in windows (only sockets)
              # https://bugs.ruby-lang.org/issues/5954
              # throw a proper error, then!!! ('Errno::EBADF: Bad file descriptor' is useless)
              stream << readable.readpartial(buffer_size)
            rescue IO::WaitReadable, EOFError => e
              # Need to read all of both streams
              # Keep going until thread dies
            end
          end
        end

        # Give Ruby time to clean up the other thread
        sleep cleanup_sleep

        killed = false

        if thread.alive?
          # We need to kill the process, because killing the thread leaves
          # the process alive but detached, annoyingly enough.
          Process.kill('KILL', pid)

          killed = true
        end

        yield output, error, thread, !time_remaining, killed
      end
    end

    def log_options(options, description)
      Logging::logger.warn "AudioBase - Provided parameters at #{description}: #{options}"
    end

  end
end