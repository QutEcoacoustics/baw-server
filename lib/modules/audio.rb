require 'open3'
require File.dirname(__FILE__) + '/string'
require File.dirname(__FILE__) + '/hash'
require File.dirname(__FILE__) + '/audio_sox'
require File.dirname(__FILE__) + '/audio_mp3splt'
require File.dirname(__FILE__) + '/audio_wavpack'
require File.dirname(__FILE__) + '/audio_ffmpeg'
require File.dirname(__FILE__) + '/exceptions'

# the audio
module MediaTools
  class AudioMaster

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

      result = {}

      sox = @audio_sox.info source
      result = result.deep_merge sox

      ffmpeg = @audio_ffmpeg.info source
      result = result.deep_merge ffmpeg

      wavpack = @audio_wavpack.info source
      result = result.deep_merge wavpack

      #TODO: what to do if there is an error?

      # extract only necessary information into a flattened hash
      info_flattened = {
          media_type: @audio_ffmpeg.get_mime_type(result[:info][:ffmpeg]),
          sample_rate_hertz: result[:info][:ffmpeg]['STREAM sample_rate'].to_f,
      }

      if info_flattened[:media_type] == 'audio/wavpack'
        info_flattened[:bit_rate_bps] = result[:info][:wavpack]['ave bitrate'].to_f
        info_flattened[:data_length_bytes] = result[:info][:wavpack]['file size'].to_f
        info_flattened[:channels] = result[:info][:wavpack]['channels'].to_i
        info_flattened[:duration_seconds] = result[:info][:wavpack]['duration'].to_f
      else
        info_flattened[:bit_rate_bps] = result[:info][:ffmpeg]['FORMAT bit_rate'].to_i
        info_flattened[:data_length_bytes] = result[:info][:ffmpeg]['FORMAT size'].to_i
        info_flattened[:channels] = result[:info][:ffmpeg]['STREAM channels'].to_i
        info_flattened[:duration_seconds] = @audio_ffmpeg.parse_duration(result[:info][:ffmpeg]['FORMAT duration']).to_f
      end

      info_flattened
    end

    # Creates a new audio file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options:
    # :start_offset :end_offset :channel :sample_rate :format
    def modify(source, target, modify_parameters)
      raise ArgumentError, "Source and Target are the same file: #{target}" unless source != target
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target

      if source.match(/\.wv$/)
        # convert to wav, then to target file (might need to change channels or sample rate or format)
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
  end
end
