require 'open3'
require File.dirname(__FILE__) + '/string'
require File.dirname(__FILE__) + '/hash'
require File.dirname(__FILE__) + '/audio_sox'
require File.dirname(__FILE__) + '/audio_mp3splt'
require File.dirname(__FILE__) + '/audio_wavpack'
require File.dirname(__FILE__) + '/audio_ffmpeg'
require File.dirname(__FILE__) + '/audio_shntool'
require File.dirname(__FILE__) + '/exceptions'
require File.dirname(__FILE__) + '/logger'

# the audio
module MediaTools
  class AudioMaster
    include Logging

    attr_reader :audio_ffmpeg, :audio_mp3splt, :audio_sox, :audio_wavpack, :temp_dir, :max_duration_seconds

    public

    def initialize(temp_dir)
      @temp_dir = temp_dir

      ffmpeg_executable = OS.windows? ? "./vendor/bin/ffmpeg/ffmpeg.exe" : "ffmpeg"
      ffprobe_executable = OS.windows? ? "./vendor/bin/ffmpeg/ffprobe.exe" : "ffprobe"
      mp3splt_executable = OS.windows? ? "./vendor/bin/mp3splt/mp3splt.exe" : "mp3splt"
      sox_executable = OS.windows? ? "./vendor/bin/sox/sox.exe" : "sox"
      wavpack_executable = OS.windows? ? "./vendor/bin/wavpack/wvunpack.exe" : "wvunpack"
      shntool_executable = OS.windows? ? "./vendor/bin/shntool/shntool.exe" : "shntool"

      @audio_ffmpeg = AudioFfmpeg.new(ffmpeg_executable, ffprobe_executable, @temp_dir)
      @audio_mp3splt = AudioMp3splt.new(mp3splt_executable, @temp_dir)
      @audio_sox = AudioSox.new(sox_executable, @temp_dir)
      @audio_wavpack = AudioWavpack.new(wavpack_executable, @temp_dir)
      @audio_shntool = AudioShntool.new(shntool_executable, @temp_dir)

      @max_duration_seconds = 300
    end

    # @return Path to a file. The file does not exist.
    def temp_file(extension)
      File.join(@temp_dir, SecureRandom.hex(7)+'.'+extension.trim('.', '')).to_s
    end

    # Provides information about an audio file.
    def info(source)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if File.size(source) < 1

      ffmpeg_info_cmd = @audio_ffmpeg.info_command(source)
      ffmpeg_info_output = execute(ffmpeg_info_cmd)
      ffmpeg_info = @audio_ffmpeg.parse_ffprobe_output(ffmpeg_info_output[:stdout])

      @audio_ffmpeg.check_for_errors(ffmpeg_info_output[:stdout], ffmpeg_info_output[:stderr])

      # extract only necessary information into a flattened hash
      info_flattened = {
          media_type: @audio_ffmpeg.get_mime_type(ffmpeg_info),
          sample_rate_hertz: ffmpeg_info['STREAM sample_rate'].to_f
      }

      if info_flattened[:media_type] == 'audio/wav' ||
          info_flattened[:media_type] == 'audio/mp3' ||
          info_flattened[:media_type] == 'audio/ogg'

        #sox_info_cmd = @audio_sox.info_command_info(source)
        #sox_info_output = execute(sox_info_cmd)
        #sox_info = @audio_sox.parse_info_output(sox_info_output[:stdout])

        sox_stat_cmd = @audio_sox.info_command_stat(source)
        sox_stat_output = execute(sox_stat_cmd)
        sox_stat = @audio_sox.parse_info_output(sox_stat_output[:stderr])

        @audio_sox.check_for_errors(sox_stat_output[:stdout], sox_stat_output[:stderr])
        info_flattened[:max_amplitude] = sox_stat['Maximum amplitude'].to_f
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
        info_flattened[:bit_rate_bps] = ffmpeg_info['FORMAT bit_rate'].to_i
        info_flattened[:data_length_bytes] = ffmpeg_info['FORMAT size'].to_i
        info_flattened[:channels] = ffmpeg_info['STREAM channels'].to_i
        info_flattened[:duration_seconds] = @audio_ffmpeg.parse_duration(ffmpeg_info['FORMAT duration']).to_f
      end

      Logging::logger.debug "Info for #{source}: #{info_flattened.to_json}"

      info_flattened
    end

    # Creates a new audio file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options:
    # :start_offset :end_offset :channel :sample_rate :format
    def modify(source, target, modify_parameters = {})
      raise ArgumentError, "Source and Target are the same file: #{target}" unless source != target
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target

      check_offsets(modify_parameters)

      source_info = info(source)

      modify_worker(source_info, source, target, modify_parameters)
    end

    def execute(command)
      stdout_str, stderr_str, status = Open3.capture3(command)

      msg = "Command status #{status.exitstatus}, executed #{command}"

      if !stderr_str.blank? && status.exitstatus != 0
        Logging::logger.warn msg+"\n\t Standard output: #{stdout_str}\n\t Standard Error: #{stderr_str}"
      else
        Logging::logger.debug msg
      end

      {
          command: command,
          stdout: stdout_str,
          stderr: stderr_str,
          status: status
      }
    end

    private

    def modify_worker(source_info, source, target, modify_parameters = {})
      if source_info[:media_type] == 'audio/wavpack'
        # convert to wave and segment
        audio_tool_segment('wav', :modify_wavpack, source, target, modify_parameters)
      elsif source_info[:media_type] == 'audio/mp3' && (modify_parameters.include?(:start_offset) || modify_parameters.include?(:end_offset))
        # segment only, so check for offsets
        audio_tool_segment('mp3', :modify_mp3splt, source, target, modify_parameters)
        #elsif source_info[:media_type] == 'audio/wav' && (modify_parameters.include?(:start_offset) || modify_parameters.include?(:end_offset))
        #  # segment only, so check for offsets
        #  audio_tool_segment('wav', :modify_shntool, source, target, modify_parameters)
      else

        start_offset = modify_parameters.include?(:start_offset) ? modify_parameters[:start_offset] : nil
        end_offset = modify_parameters.include?(:end_offset) ? modify_parameters[:end_offset] : nil
        channel = modify_parameters.include?(:channel) ? modify_parameters[:channel] : nil
        sample_rate = modify_parameters.include?(:sample_rate) ? modify_parameters[:sample_rate] : nil

        if modify_parameters.include?(:sample_rate)

          # Convert to wav first to avoid problems with other formats
          temp_file_1 = temp_file('wav')
          cmd = @audio_ffmpeg.modify_command(source, temp_file_1, start_offset, end_offset)
          execute(cmd)
          check_target(temp_file_1)

          # resample using sox.
          temp_file_2 = temp_file('wav')
          cmd = @audio_sox.modify_command(temp_file_1, temp_file_2, nil, nil, channel, sample_rate)
          execute(cmd)
          check_target(temp_file_2)

          # convert to requested format after resampling
          cmd = @audio_ffmpeg.modify_command(temp_file_2, target)
          execute(cmd)
          check_target(temp_file_1)

          File.delete temp_file_1
          File.delete temp_file_2
        else
          # use ffmpeg for anything else
          cmd = @audio_ffmpeg.modify_command(source, target, start_offset, end_offset, channel, sample_rate)
          execute(cmd)
          check_target(target)
        end

      end
    end

    def modify_wavpack(source, target, start_offset, end_offset)
      cmd = @audio_wavpack.modify_command(source, target, start_offset, end_offset)
      execute(cmd)
    end

    def modify_mp3splt(source, target, start_offset, end_offset)
      cmd = @audio_mp3splt.modify_command(source, target, start_offset, end_offset)
      execute(cmd)
    end

    def modify_shntool(source, target, start_offset, end_offset)
      cmd = @audio_shntool.modify_command(source, target, start_offset, end_offset)
      execute(cmd)
    end

    def audio_tool_segment(extension, audio_tool_method, source, target, modify_parameters)
      # process the source file, put output to temp file
      temp_file = temp_file(extension)
      self.send(audio_tool_method, source, temp_file, modify_parameters[:start_offset], modify_parameters[:end_offset])
      check_target(temp_file)

      # remove start and end offset from modify_parameters (otherwise it will be done again!)
      modify_parameters.delete :start_offset if modify_parameters.include?(:start_offset)
      modify_parameters.delete :end_offset if  modify_parameters.include?(:end_offset)

      # more processing might be required
      modify_worker(info(temp_file), temp_file, target, modify_parameters)

      File.delete temp_file
    end

    def check_offsets(modify_parameters = {})
      start_offset = 0
      end_offset = @max_duration_seconds

      if modify_parameters.include? :start_offset
        start_offset = modify_parameters[:start_offset]
      end

      if modify_parameters.include? :end_offset
        end_offset = modify_parameters[:end_offset]
      end

      if end_offset < start_offset
        temp_end_offset = end_offset
        end_offset = start_offset
        start_offset = temp_end_offset
      end

      duration = end_offset - start_offset
      raise Exceptions::SegmentRequestTooLong, "#{end_offset} - #{start_offset} = #{duration} (max: #{@max_duration_seconds})" if duration > @max_duration_seconds

      modify_parameters[:start_offset] = start_offset
      modify_parameters[:end_offset] = end_offset
      modify_parameters[:duration] = duration
    end

    def check_target(target)
      raise Exceptions::AudioFileNotFoundError, "#{target}" unless File.exists?(target)
      raise Exceptions::FileEmptyError, "#{target}" if File.size(target) < 1
    end

  end
end
