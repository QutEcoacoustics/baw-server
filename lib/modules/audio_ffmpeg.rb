require 'logger'

module MediaTools
  class AudioFfmpeg
    include Logging

    def initialize(ffmpeg_executable, ffprobe_executable, temp_dir)
      @ffmpeg_executable = ffmpeg_executable
      @ffprobe_executable = ffprobe_executable
      @temp_dir = temp_dir
    end

    # public methods
    public

    # mime type to ffmpeg string identifier conversions
    def get_mime_type(ffmpeg_info)

      #[:info][:ffmpeg]['STREAM codec_type']+'/'+file_info[:info][:ffmpeg]['STREAM codec_name']

      case ffmpeg_info['FORMAT format_long_name']
        when 'WAV / WAVE (Waveform Audio)'
          # :codec_name => 'pcm_s16le',
          # :codec_long_name => 'PCM signed 16-bit little-endian',
          'audio/wav'
        when 'MP2/3 (MPEG audio layer 2/3)', 'MP3 (MPEG audio layer 3)'
          # :codec_name => 'mp3',
          # :codec_long_name => 'MP3 (MPEG audio layer 3)',
          'audio/mp3'
        when 'Matroska / WebM', 'WebM'
          # :codec_name => 'vorbis',
          # :codec_long_name => 'Vorbis',
          # :format_name => 'matroska,webm',
          'audio/webm'
        when 'Ogg'
          # :codec_name => 'vorbis',
          # :codec_long_name => 'Vorbis',
          'audio/ogg'
        when 'ASF (Advanced / Active Streaming Format)'
          # :codec_name => 'wmav2',
          # :codec_long_name => 'Windows Media Audio 2',
          'audio/asf'
        when 'WavPack', 'raw WavPack'
          # :codec_name => 'wavpack',
          # :codec_long_name => 'WavPack',
          'audio/wavpack'
        when 'QuickTime / MOV', 'MP4 (MPEG-4 Part 14)', 'PSP MP4 (MPEG-4 Part 14)', 'iPod H.264 MP4 (MPEG-4 Part 14)'
          # codec_name=alac
          # codec_long_name=ALAC (Apple Lossless Audio Codec)
          # format_name=mov,mp4,m4a,3gp,3g2,mj2
          'audio/mp4'
        when 'AAC (Advanced Audio Coding)', 'AAC LATM (Advanced Audio Coding LATM syntax)', 'ADTS AAC (Advanced Audio Coding)'
          # codec_name=aac
          # codec_long_name=AAC (Advanced Audio Coding)
          # format_name=aac
          'audio/aac'
        else
          'application/octet-stream'
      end
    end

    def info(source)
      result = {
          :info => {:ffmpeg => {}},
          :error => {:ffmpeg => {}}
      }
      ffprobe_arguments_info = "-sexagesimal -print_format default -show_error -show_streams -show_format"
      ffprobe_command = "#{@ffprobe_executable} #{ffprobe_arguments_info} \"#{source}\""
      ffprobe_stdout_str, ffprobe_stderr_str, ffprobe_status = Open3.capture3(ffprobe_command)

      Logging::logger.debug "Ffprobe info return status #{ffprobe_status.exitstatus}. Command: #{ffprobe_command}"


      ffprobe_std_info = parse_ffprobe_output(ffprobe_stdout_str)
      if ffprobe_status.exitstatus == 0
        result[:info][:ffmpeg] = ffprobe_std_info
      else
        result[:error][:ffmpeg] = ffprobe_std_info
      end

      if ffprobe_status.exitstatus != 0 && !ffprobe_stderr_str.blank?
        result[:error][:ffmpeg][:stderror] = ffprobe_stderr_str
      end

      unless result[:error][:ffmpeg].blank?
        Logging::logger.error "Ffprobe info error: #{result[:error][:ffmpeg]}"
      end

      if result[:info][:ffmpeg]['STREAM codec_type'] != 'audio'
        result[:error][:ffmpeg][:file_type] = 'Not an audio file.'
        Logging::logger.warn "Ffprobe gave info about a non-audio file: #{result[:info][:ffmpeg]}"
      end

      result
    end

    def modify(source, target, modify_parameters = {})
      # ffmpeg is the catch-all, so it will do anything specified in modify_parameters.

      raise ArgumentError, "Source is a wavpack file, use wavpack to convert to .wav first instead: #{source}" if source.match(/\.wv$/)

      raise ArgumentError, "Source does not exist: #{source}" unless File.exists? source
      raise ArgumentError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      arguments = ''

      # start offset
      # -ss Seek to given time position in seconds. hh:mm:ss[.xxx] syntax is also supported.
      if modify_parameters.include? :start_offset
        start_offset_formatted = Time.at(modify_parameters[:start_offset].to_i).utc.strftime('%H:%M:%S.%3N')
        arguments += " -ss #{start_offset_formatted}"
      end

      # end offset
      # -t Restrict the transcoded/captured video sequence to the duration specified in seconds. hh:mm:ss[.xxx] syntax is also supported.
      if modify_parameters.include? :end_offset
        #end_offset_formatted = Time.at(modify_parameters[:end_offset]).utc.strftime('%H:%M:%S.%3N')
        end_offset_raw = modify_parameters[:end_offset].to_f
        end_offset_time = Time.at(end_offset_raw).utc
        if modify_parameters.include? :start_offset
          start_offset_raw = modify_parameters[:start_offset].to_f
          start_offset_time = Time.at(start_offset_raw).utc
          arguments += " -t #{Time.at(end_offset_raw - start_offset_raw).utc.strftime('%H:%M:%S.%3N')}"
        else
          # if start offset was not included, include audio from the start of the file.
          arguments += " -t #{end_offset_time.strftime('%H:%M:%S.%3N')}"
        end
      end

      # -ar Set the audio sampling frequency (default = 44100 Hz).
      # -ab Set the audio bitrate in bit/s (default = 64k).
      if modify_parameters.include? :sample_rate
        arguments += " -ar #{modify_parameters[:sample_rate]}"
      end

      # set the right codec if we know it
      # -acodec Force audio codec to codec. Use the copy special value to specify that the raw codec data must be copied as is.
      # output file. extension used to determine filetype.
      ext_to_copy_to = ''
      vorbis_codec = 'libvorbis -aq 80' # ogg container vorbis encoder at quality level of 80
      codec = ''
      case File.extname(target).upcase!.reverse.chomp('.').reverse
        when 'WAV'
          codec = "pcm_s16le" # pcm signed 16-bit little endian - compatible with CDDA
        when 'MP3'
          codec = "libmp3lame" # needs to be specified, different codecs for encoding and decoding
        when 'OGG'
          codec = vorbis_codec
        when 'OGA'
          codec = vorbis_codec
          target = target.chomp(File.extname(target))+'.ogg'
          ext_to_copy_to = 'oga'
        when 'WEBM'
          codec = vorbis_codec
        when 'WEBMA'
          codec = vorbis_codec
          target = target.chomp(File.extname(target))+'.webm'
          ext_to_copy_to = 'webma'
        when 'WV'
          codec = 'wavpack'
        else
          codec = 'copy'
      end
      arguments += " -acodec #{codec}"

      if modify_parameters.include? :channel
        channel_number = modify_parameters[:channel].to_i
        if channel_number < 1
          # mix down to mono
          arguments += ' -ac 1 '
        else
          # select the channel (0 index based)
          arguments += " -map_channel 0.0.#{channel_number - 1} "
        end
      end

      ffmpeg_command = "#{@ffmpeg_executable} -i \"#{source}\" #{arguments} \"#{target}\""
      ffmpeg_stdout_str, ffmpeg_stderr_str, ffmpeg_status = Open3.capture3(ffmpeg_command)

      Logging::logger.debug "Ffmpeg info return status #{ffmpeg_status.exitstatus}. Command: #{ffmpeg_command}"

      if !File.exists?(target) || (!ffmpeg_stderr_str.blank? && ffmpeg_status.exitstatus != 0)
        Logging::logger.error "Ffmpeg exited with an error: #{ffmpeg_stderr_str}"
      end

      if ext_to_copy_to.length > 0
        new_target = target.chomp(File.extname(target))+'.'+ext_to_copy_to
        FileUtils.copy target, new_target
      end

      {
          info: {
              ffmpeg: {
                  command: ffmpeg_command,
                  source: source,
                  target: target,
                  parameters: modify_parameters
              }
          }
      }
    end

    # returns the duration in seconds (and fractions if present)
    def parse_duration(duration_string)
      duration_match = /(?<hour>\d+):(?<minute>\d+):(?<second>[\d+\.]+)/i.match(duration_string)
      duration = 0
      if !duration_match.nil? && duration_match.size == 4
        duration = (duration_match[:hour].to_f * 60 * 60) + (duration_match[:minute].to_f * 60) + duration_match[:second].to_f
      end
      duration
    end

    private

    def parse_ffprobe_output(raw)
      # ffprobe std err contains info (separate on first equals(=))
      result = {}
      ffprobe_current_block_name = ''
      raw.strip.split(/\r?\n|\r/).each do |line|
        line.strip!
        if line[0] == '['
          # this chomp reverse stuff is due to the lack of a proper 'trim'
          ffprobe_current_block_name = line.chomp(']').reverse.chomp('[').reverse
        else
          current_key = line[0, line.index('=')].strip
          current_value = line[line.index('=')+1, line.length].strip
          result[ffprobe_current_block_name + ' ' + current_key] = current_value
        end
      end

      result
    end

  end
end