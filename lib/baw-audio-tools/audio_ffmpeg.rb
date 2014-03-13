module BawAudioTools
  class AudioFfmpeg

    WARN_ESTIMATE_DURATION = 'Estimating duration from bitrate, this may be inaccurate'

    def initialize(ffmpeg_executable, ffprobe_executable, temp_dir)
      @ffmpeg_executable = ffmpeg_executable
      @ffprobe_executable = ffprobe_executable
      @temp_dir = temp_dir
    end

    public

    def info_command(source)
      "#{@ffprobe_executable} -sexagesimal -print_format default -show_error -show_streams -show_format \"#{source}\""
    end

    def modify_command(source, source_info, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      cmd_offsets = arg_offsets(start_offset, end_offset)
      cmd_sample_rate = arg_sample_rate(sample_rate)

      if sample_rate.blank? && source_info.include?(:sample_rate)
        cmd_sample_rate = arg_sample_rate(source_info[:sample_rate])
      else
        cmd_sample_rate = arg_sample_rate(sample_rate)
      end

      cmd_channel = arg_channel(channel)
      codec_info = codec_calc(target)

      audio_cmd = "#{@ffmpeg_executable} -i \"#{source}\" #{cmd_offsets} #{cmd_sample_rate} #{cmd_channel} #{codec_info.codec} \"#{codec_info.target}\""
      cmd = ''

      if codec_info[:target] == codec_info[:old_target]
        cmd = audio_cmd
      else
        partial_cmd = "\"#{codec_info[:target]}\" \"#{codec_info[:old_target]}\""
        separator_move = OS.windows? ? '&& move' : '; mv'
        cmd = "#{audio_cmd} #{separator_move} #{partial_cmd}"
      end

      cmd
    end

    def check_for_errors(stdout, stderr)

      unless stderr.blank?

        ffmpeg_warning_tag = '\[[^ ]+ @ [^ ]+\] '

        mod_stderr = stderr
        if stderr.include?(WARN_ESTIMATE_DURATION)
          mod_stderr = mod_stderr.gsub(/#{ffmpeg_warning_tag}#{WARN_ESTIMATE_DURATION}/, '')
        end
        raise Exceptions::FileCorruptError if !mod_stderr.blank? && mod_stderr.match(/#{ffmpeg_warning_tag}/)
      end
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

    def parse_ffprobe_output(source, raw)
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

      raise Exceptions::NotAnAudioFileError, "Not an audio file #{source}: #{result.to_json}" if result['STREAM codec_type'] != 'audio'

      result
    end

    def arg_channel(channel)
      cmd_arg = ''
      unless channel.blank?
        channel_number = channel.to_i
        if channel_number < 1
          # mix down to mono
          cmd_arg = ' -ac 1 '
        else
          # select the channel (0 index based)
          cmd_arg = " -map_channel 0.0.#{channel_number - 1} "
        end
      end
      cmd_arg
    end

    def arg_sample_rate(sample_rate)
      cmd_arg = ''
      unless sample_rate.blank?
        # -ar Set the audio sampling frequency (default = 44100 Hz).
        # -ab Set the audio bitrate in bit/s (default = 64k).
        cmd_arg = " -ar #{sample_rate} "
      end
      cmd_arg
    end

    def arg_offsets(start_offset, end_offset)
      cmd_arg = ''

      # start offset
      # -ss Seek to given time position in seconds. hh:mm:ss[.xxx] syntax is also supported.
      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%3N')
        cmd_arg = " -ss #{start_offset_formatted}"
      end

      # end offset
      # -t Restrict the transcoded/captured video sequence to the duration specified in seconds. hh:mm:ss[.xxx] syntax is also supported.
      unless end_offset.blank?
        #end_offset_formatted = Time.at(modify_parameters[:end_offset]).utc.strftime('%H:%M:%S.%3N')
        end_offset_raw = end_offset.to_f
        end_offset_time = Time.at(end_offset_raw).utc
        if start_offset.blank?
          # if start offset was not included, include audio from the start of the file.
          cmd_arg += " -t #{end_offset_time.strftime('%H:%M:%S.%3N')}"
        else
          start_offset_raw = start_offset.to_f
          #start_offset_time = Time.at(start_offset_raw).utc
          cmd_arg += " -t #{Time.at(end_offset_raw - start_offset_raw).utc.strftime('%H:%M:%S.%3N')}"
        end
      end

      cmd_arg
    end

    def codec_calc(target)

      # high quality codec settings
      # https://trac.ffmpeg.org/wiki/GuidelinesHighQualityAudio

      # http://trac.ffmpeg.org/wiki/TheoraVorbisEncodingGuide
      # http://en.wikipedia.org/wiki/Vorbis#Technical_details
      # http://wiki.hydrogenaudio.org/index.php?title=Recommended_Ogg_Vorbis#Recommended_Encoder_Settings
      # -aq 6 will be approx 192kbit/s
      codec_high_vorbis = 'libvorbis -aq 6'

      # pcm signed 16-bit little endian - compatible with CDDA
      codec_high_wav = 'pcm_s16le'

      # http://lame.cvs.sourceforge.net/viewvc/lame/lame/USAGE
      # 0 = slowest algorithms, but potentially highest quality
      # 9 = faster algorithms, very poor quality
      # http://trac.ffmpeg.org/wiki/Encoding%20VBR%20(Variable%20Bit%20Rate)%20mp3%20audio
      # -aq 2 recommended, but still cuts off at 10khz at 22.05khz
      # using CBR: -b:a 192k
      codec_high_mp3 = 'libmp3lame -aq 0'

      codec_high_wavpack = 'wavpack'

      codec_high_flac = 'flac'

      # output file. extension used to determine filetype.
      old_target = target

      # set the right codec if we know it
      codec = ''
      extension = File.extname(target).upcase!.reverse.chomp('.').reverse
      case extension
        when 'WAV'
          codec = codec_high_wav
        when 'MP3'
          codec = codec_high_mp3
        when 'OGG'
          codec = codec_high_vorbis
        when 'OGA'
          codec = codec_high_vorbis
          target = target.chomp(File.extname(target))+'.ogg'
        when 'WEBM'
          codec = codec_high_vorbis
        when 'WEBMA'
          codec = codec_high_vorbis
          target = target.chomp(File.extname(target))+'.webm'
        when 'WV'
          codec = codec_high_wavpack
        when 'FLAC'
          codec = codec_high_flac
        else
          # don't specify codec for any other extension
          # Alternative: Use the 'copy' special value to specify that the raw codec data must be copied as is.
          codec = ''
      end

      # -acodec Force audio codec to codec.
      {
          codec: codec.blank? ? '' : " -acodec #{codec}",
          target: target,
          old_target: old_target
      }

    end

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
        when 'AAC (Advanced Audio Coding)', 'AAC LATM (Advanced Audio Coding LATM syntax)',
            'ADTS AAC (Advanced Audio Coding)', 'raw ADTS AAC (Advanced Audio Coding)'
          # codec_name=aac
          # codec_long_name=AAC (Advanced Audio Coding)
          # format_name=aac
          'audio/aac'
        when 'FLAC (Free Lossless Audio Codec)', 'raw FLAC', 'flac'
          # codec_name=flac
          # codec_long_name=raw FLAC
          # format_name=flac
          'audio/x-flac'
        else
          'application/octet-stream'
      end
    end

  end
end