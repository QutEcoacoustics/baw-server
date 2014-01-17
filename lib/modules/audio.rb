require 'open3'
require File.dirname(__FILE__) + '/string'
require File.dirname(__FILE__) + '/hash'
require File.dirname(__FILE__) + '/audio_sox'
require File.dirname(__FILE__) + '/audio_mp3splt'
require File.dirname(__FILE__) + '/audio_wavpack'
require File.dirname(__FILE__) + '/audio_ffmpeg'
require File.dirname(__FILE__) + '/exceptions'
require File.dirname(__FILE__) + '/logger'

# the audio
module MediaTools
  class AudioMaster
    include Logging

    attr_reader :audio_ffmpeg, :audio_mp3splt, :audio_sox, :audio_wavpack, :temp_dir

    public

    def initialize(temp_dir)
      @temp_dir = temp_dir

      ffmpeg_executable = OS.windows? ? "./vendor/bin/ffmpeg/ffmpeg.exe" : "ffmpeg"
      ffprobe_executable = OS.windows? ? "./vendor/bin/ffmpeg/ffprobe.exe" : "ffprobe"
      mp3splt_executable = OS.windows? ? "./vendor/bin/mp3splt/mp3splt.exe" : "mp3splt"
      sox_executable = OS.windows? ? "./vendor/bin/sox/sox.exe" : "sox"
      wavpack_executable = OS.windows? ? "./vendor/bin/wavpack/wvunpack.exe" : "wvunpack"

      @audio_ffmpeg = AudioFfmpeg.new(ffmpeg_executable, ffprobe_executable, @temp_dir)
      @audio_mp3splt = AudioMp3splt.new(mp3splt_executable, @temp_dir)
      @audio_sox = AudioSox.new(sox_executable, @temp_dir)
      @audio_wavpack = AudioWavpack.new(wavpack_executable, @temp_dir)
    end

    # @return Path to a file. The file does not exist.
    def temp_file(extension)
      path = File.join(@temp_dir, SecureRandom.hex(7)+'.'+extension.trim('.', '')).to_s
      path
    end

    # Provides information about an audio file.
    def info(source)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if File.size(source) < 1

      #sox_info_cmd = @audio_sox.info_command_info(source)
      #sox_info_output = execute(sox_info_cmd)
      #sox_info = @audio_sox.parse_info_output(sox_info_output[:stdout])

      sox_stat_cmd = @audio_sox.info_command_stat(source)
      sox_stat_output = execute(sox_stat_cmd)
      sox_stat = @audio_sox.parse_info_output(sox_stat_output[:stderr])

      ffmpeg_info_cmd = @audio_ffmpeg.info_command(source)
      ffmpeg_info_output = execute(ffmpeg_info_cmd)
      ffmpeg_info = @audio_ffmpeg.parse_ffprobe_output(ffmpeg_info_output[:stdout])

      @audio_sox.check_for_errors(sox_stat_output[:stdout],sox_stat_output[:stderr])
      @audio_ffmpeg.check_for_errors(ffmpeg_info_output[:stdout],ffmpeg_info_output[:stderr])

      # extract only necessary information into a flattened hash
      info_flattened = {
          media_type: @audio_ffmpeg.get_mime_type(ffmpeg_info),
          sample_rate_hertz: ffmpeg_info['STREAM sample_rate'].to_f,
          max_amplitude: sox_stat['Maximum amplitude'].to_f
      }

      if info_flattened[:media_type] == 'audio/wavpack'
        # only get wavpack info for wavpack files
        wavpack_info_cmd = @audio_wavpack.info_command(source)
        wavpack_info_output = execute(wavpack_info_cmd)
        wavpack_info = @audio_wavpack.parse_info_output(wavpack_info_output[:stdout])

        info_flattened[:bit_rate_bps] = wavpack_info['ave bitrate'].to_f
        info_flattened[:data_length_bytes] = wavpack_info['file size'].to_f
        info_flattened[:channels] = wavpack_info['channels'].to_i
        info_flattened[:duration_seconds] = wavpack_info['duration'].to_f

      elsif info_flattened[:media_type] == 'audio/wav'
        # only get shntool info for wav files
        shntool_info_cmd = @audio_shntool.info_command(source)
        shntool_info_output = execute(shntool_info_cmd)
        shntool_info = @audio_shntool.parse_info_output(shntool_info_output[:stdout])

        info_flattened[:bit_rate_bps] = shntool_info['ave bitrate'].to_f
        info_flattened[:data_length_bytes] = shntool_info['file size'].to_f
        info_flattened[:channels] = shntool_info['channels'].to_i
        info_flattened[:duration_seconds] = shntool_info['duration'].to_f

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
    def modify(source, target, modify_parameters)
      raise ArgumentError, "Source and Target are the same file: #{target}" unless source != target
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target

      # first get info about the source file
      source_info = info(source)

      # convert to wav, then to target file (might need to change channels or sample rate or format)
      if source_info[:media_type] == 'audio/wavpack'

        # put the wav file in a temp location
        temp_wav_file = temp_file('wav')
        @audio_wavpack.modify(source, temp_wav_file, modify_parameters)

        # remove start and end offset from modify_parameters (otherwise it will be done again!)
        wav_to_modify_params = modify_parameters.clone
        wav_to_modify_params.delete :start_offset if modify_parameters.include?(:start_offset)
        wav_to_modify_params.delete :end_offset if  modify_parameters.include?(:end_offset)

        modify(temp_wav_file, target, wav_to_modify_params)

        File.delete temp_wav_file

      elsif source.match(/\.mp3$/) && (modify_parameters.include?(:start_offset) || modify_parameters.include?(:end_offset))
        # segment the mp3, then to target file (might need to change channels or sample rate or format)
        # put the mp3 file in a temp location
        temp_wav_file = temp_file('mp3')
        @audio_mp3splt.modify(source, temp_wav_file, modify_parameters)

        # remove start and end offset from modify_parameters (otherwise it will be done again!)
        wav_to_modify_params = modify_parameters.clone
        wav_to_modify_params.delete :start_offset
        wav_to_modify_params.delete :end_offset

        modify(temp_wav_file, target, wav_to_modify_params)

        File.delete temp_wav_file

      elsif source.match(/\.wav$/)&& target.match(/\.mp3$/)
        @audio_sox.modify(source, target, modify_parameters)

      else
        @audio_ffmpeg.modify(source, target, modify_parameters)

      end

    end

    private

    def modify_private(info, source, target, modify_parameters)

    end

    def execute(command)
      stdout_str, stderr_str, status = Open3.capture3(command)

      msg = "Command status #{status.exitstatus}, executed #{command}"

      if !stderr_str.blank? && status.exitstatus != 0
        Logging::logger.warn msg+"\n Standard output: #{stdout_str}\n Standard Error: #{stderr_str}"
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

  end
end
