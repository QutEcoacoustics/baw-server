# frozen_string_literal: true

module BawAudioTools
  class AudioFfmpeg
    ERROR_FRAME_SIZE_1 = 'Could not find codec parameters for stream [0-9]+ \\(Audio\\: [a-zA-Z0-9]+\\, [0-9]+ channels\\, [a-zA-Z0-9]+\\)\\: unspecified frame size'
    ERROR_FRAME_SIZE_2 = 'Failed to read frame size: Could not seek to [0-9]+\\.'
    ERROR_END_OF_FILE = 'End of file'

    # @param [String] ffmpeg_executable
    # @param [String] ffprobe_executable
    # @param [Logger] logger
    # @param [String] temp_dir
    def initialize(ffmpeg_executable, ffprobe_executable, logger, temp_dir)
      @ffmpeg_executable = ffmpeg_executable
      @ffprobe_executable = ffprobe_executable
      @logger = logger
      @temp_dir = temp_dir

      @class_name = self.class.name
    end

    def info_command(source)
      "#{@ffprobe_executable} -sexagesimal -print_format default -show_error -show_streams -show_format \"#{source}\""
    end

    def integrity_command(source)
      "#{@ffmpeg_executable} -loglevel repeat+verbose -nostdin -i \"#{source}\" -codec copy -f null -"
    end

    def modify_command(source, source_info, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exist? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exist? target
      raise ArgumentError, "Source and Target are the same file: #{target}" if source == target

      cmd_offsets = arg_offsets(start_offset, end_offset)
      cmd_sample_rate = arg_sample_rate(sample_rate)

      cmd_sample_rate = if sample_rate.blank? && source_info.include?(:sample_rate)
                          arg_sample_rate(source_info[:sample_rate])
                        else
                          arg_sample_rate(sample_rate)
                        end

      cmd_channel = arg_channel(channel)
      codec_info = codec_calc(target)

      audio_cmd = "#{@ffmpeg_executable} -i \"#{source}\" #{cmd_offsets} #{cmd_sample_rate} #{cmd_channel} #{codec_info[:codec]} \"#{codec_info[:target]}\""
      cmd = ''

      if codec_info[:target] == codec_info[:old_target]
        cmd = audio_cmd
      else
        partial_cmd = "\"#{codec_info[:target]}\" \"#{codec_info[:old_target]}\""
        separator_move = '; mv'
        cmd = "#{audio_cmd} #{separator_move} #{partial_cmd}"
      end

      cmd
    end

    def check_for_errors(execute_msg)
      #stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]

      if !stderr.blank? && /#{ERROR_FRAME_SIZE_1}/.match(stderr)
        raise Exceptions::FileCorruptError, "Ffmpeg could not get frame size (msg type 1).\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && /#{ERROR_FRAME_SIZE_2}/.match(stderr)
        raise Exceptions::FileCorruptError, "Ffmpeg could not get frame size (msg type 2).\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && /#{ERROR_END_OF_FILE}/i.match(stderr)
        raise Exceptions::FileCorruptError, "Ffmpeg encountered unexpected end of file.\n\t#{execute_msg[:execute_msg]}"
      end
    end

    def check_integrity_output(execute_msg)
      #stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]

      result = {
        errors: [],
        warnings: [],
        info: {
          read: {
            packets: 0, bytes: 0, frames: 0, samples: 0
          },
          write: {
            packets: 0, bytes: 0, frames: 0, samples: 0
          }
        }
      }

      return result if stderr.blank?

      stderr.each_line do |line|
        match_result = /\A\[(.+?) @ 0x.+?\] (.*)/.match(line)
        item = nil
        item = check_integrity_item(id: match_result[1], description: match_result[2]) unless match_result.blank?
        result[:warnings].push(item) unless item.blank?

        if /: End of file$/ =~ line
          result[:warnings].push(id: 'end of file', description: 'End of file')
        end

        read_packets_match = /Total: (\d+) packets \((\d+) bytes\) demuxed/.match(line)
        unless read_packets_match.blank?
          result[:info][:read][:packets] = read_packets_match[1]
          result[:info][:read][:bytes] = read_packets_match[2]
        end

        read_frames_match = /(\d+) frames decoded \((\d+) samples\);/.match(line)
        unless read_frames_match.blank?
          result[:info][:read][:frames] = read_frames_match[1]
          result[:info][:read][:samples] = read_frames_match[2]
        end

        write_packets_match = /Total: (\d+) packets \((\d+) bytes\) muxed/.match(line)
        unless write_packets_match.blank?
          result[:info][:write][:packets] = write_packets_match[1]
          result[:info][:write][:bytes] = write_packets_match[2]
        end

        write_frames_match = /(\d+) frames encoded \((\d+) samples\);/.match(line)
        unless write_frames_match.blank?
          result[:info][:write][:frames] = write_frames_match[1]
          result[:info][:write][:samples] = write_frames_match[2]
        end
      end

      result
    end

    def check_integrity_item(hash)
      return nil if hash.blank?

      return nil if hash[:id].starts_with?('graph')
      return nil if hash[:id].starts_with?('audio format')
      return nil if hash[:id].starts_with?('auto-inserted')

      return nil if hash[:description].starts_with?('parser not found for')
      return nil if hash[:description].starts_with?('max_analyze_duration')
      if hash[:description].starts_with?('Application provided invalid, non monotonically increasing dts to muxer in stream')
        return nil
      end

      hash
    end

    def find_remove_warning(mod_stderr, match_regex)
      match_info = mod_stderr.match(match_regex)
      mod_stderr = mod_stderr.gsub(match_regex, '')

      unless match_info.blank?
        @logger.warn(@class_name) {
          "Found and removed '#{match_info}' in ffmpeg output."
        }
      end

      mod_stderr
    end

    def has_regex?(string, regex)
      !!(string =~ regex)
    end

    # returns the duration in seconds (and fractions if present)
    def parse_duration(duration_string)
      duration_match = /(?<hour>\d+):(?<minute>\d+):(?<second>[\d+.]+)/i.match(duration_string)
      duration = 0
      if !duration_match.nil? && duration_match.size == 4
        duration = (duration_match[:hour].to_f * 60 * 60) + (duration_match[:minute].to_f * 60) + duration_match[:second].to_f
      end
      duration
    end

    def parse_ffprobe_output(source, execute_msg)
      # ffprobe std err contains info (separate on first equals(=))

      result = {}
      ffprobe_current_block_name = ''
      execute_msg[:stdout].strip.split(/\r?\n|\r/).each do |line|
        line.strip!
        if line[0] == '['
          # this chomp reverse stuff is due to the lack of a proper 'trim'
          ffprobe_current_block_name = line.chomp(']').reverse.chomp('[').reverse
        else
          # some lines won't output key=value data, especially when FLAC metadata
          # is output as `\t\tkey\t:\tvalue` (where \t denotes a tab)
          # When encountering such lines, just skip for now.
          index = line.index('=')
          unless index.nil?
            current_key = line[0, index].strip
            current_value = line[index + 1, line.length].strip
            result[ffprobe_current_block_name + ' ' + current_key] = current_value
          end
        end
      end

      unless File.exist?(source)
        raise Exceptions::AudioFileNotFoundError, "Could not locate #{source}\n\t#{execute_msg[:execute_msg]}"
      end

      actual_stream_codec_type = result['STREAM codec_type']
      expected_stream_codec_type = 'audio'
      if actual_stream_codec_type != expected_stream_codec_type
        msg = "Not an audio file #{source} ('#{actual_stream_codec_type}' is not '#{expected_stream_codec_type}'): #{result.to_json}\n\t#{execute_msg[:execute_msg]}"
        raise Exceptions::NotAnAudioFileError, msg
      end

      result
    end

    def arg_channel(channel)
      cmd_arg = ''
      unless channel.blank?
        channel_number = channel.to_i
        cmd_arg = if channel_number < 1
                    # mix down to mono
                    ' -ac 1 '
                  else
                    # select the channel (0 index based)
                    " -map_channel 0.0.#{channel_number - 1} "
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

      # The flac reference implementation may not keep the .wav metadata
      # https://xiph.org/flac/faq.html#general__no_wave_metadata
      # The flag --keep-foreign-metadata can be included to store the WAVE non-audio data as well
      # Note that when a flac file is decoded to WAVE/AIFF the flag must be used again to keep metadata
      # The ffmpeg implementation of flac encoding / decoding can handle some metadata formats, this is sufficient until
      # there is something concrete that requires using additional ffmpeg flags or using the reference flac implementation
      # instead.
      # The relevant ffmpeg flag is `-map_metadata`. "By default, global metadata is copied from the first input file,
      # per-stream and per-chapter metadata is copied along with streams/chapters."
      codec_high_flac = 'flac'

      # output file. extension used to determine filetype.
      old_target = target

      # set the right codec if we know it
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
        target = target.chomp(File.extname(target)) + '.ogg'
      when 'WEBM'
        codec = codec_high_vorbis
      when 'WEBMA'
        codec = codec_high_vorbis
        target = target.chomp(File.extname(target)) + '.webm'
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
