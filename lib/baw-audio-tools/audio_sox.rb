module BawAudioTools
  class AudioSox

    ERROR_NO_HANDLER = 'FAIL formats: no handler for file extension'
    ERROR_CANNOT_OPEN = 'FAIL formats: can\'t open input file'

    def initialize(sox_executable, temp_dir)
      @sox_executable = sox_executable
      @temp_dir = temp_dir
    end

    def info_command_stat(source)
      # sox std err contains stat output
      "#{@sox_executable} -V2 \"#{source}\" -n stat"
    end

    def info_command_info(source)
      # sox std out contains info
      "#{@sox_executable} --info -V2 \"#{source}\""
    end

    def parse_info_output(output)
      # contains key value output (separate on first colon(:))
      result = {}
      output.strip.split(/\r?\n|\r/).each { |line|
        if line.include?(':')
          colon_index = line.index(':')
          new_value = line[colon_index+1, line.length].strip
          new_key = line[0, colon_index].strip
          result[new_key] = new_value
        end
      }

      result
    end

    def check_for_errors(stdout, stderr)
      raise Exceptions::FileCorruptError if !stderr.blank? && stderr.include?(ERROR_CANNOT_OPEN)
      raise Exceptions::AudioToolError if !stderr.blank? && stderr.include?(ERROR_NO_HANDLER)
    end

    def modify_command(source, source_info, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil)
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target


      cmd_offsets = arg_offsets(start_offset, end_offset)
      sample_rate = arg_sample_rate(sample_rate)
      cmd_channel = arg_channel(channel)

      "#{@sox_executable} -q -V4 \"#{source}\" \"#{target}\" #{cmd_offsets} #{sample_rate} #{cmd_channel}"
    end

    def spectrogram_command(source, source_info, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil,
        window = nil, window_function = nil, colour = nil)
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      cmd_offsets = arg_offsets(start_offset, end_offset)
      cmd_sample_rate = arg_sample_rate(sample_rate)
      cmd_channel = arg_channel(channel)
      cmd_window = arg_window(window)
      cmd_window_function = arg_window_function(window_function)
      cmd_colour = arg_colour(colour)

      cmd_spectrogram = 'spectrogram -r -l -a -X 43.06640625'

      # sox command to create a spectrogram from an audio file
      # -V is for verbose
      # -n indicates no output audio file
      "#{@sox_executable} -V \"#{source}\" -n #{cmd_offsets} #{cmd_sample_rate} #{cmd_channel} #{cmd_spectrogram} #{cmd_colour} #{cmd_window} #{cmd_window_function} -o \"#{target}\""
    end

    def window_options
      [128, 256, 512, 1024, 2048, 4096]
    end

    def colour_options
      {:g => :greyscale}
    end

    def window_function_options
      # Window: Hann (default), Hamming, Bartlett, Rectangular or Kaiser. The spectrogram is produced using the
      # Discrete Fourier Transform (DFT) algorithm. A significant parameter to this algorithm is the choice of
      # ‘window function’. By default, SoX uses the Hann window which has good all-round frequency-resolution
      # and dynamic-range properties. For better frequency resolution (but lower dynamic-range), select a
      # Hamming window; for higher dynamic-range (but poorer frequency-resolution), select a Kaiser window.
      # Bartlett and Rectangular windows are also available.
      %w(Hann Hamming Bartlett Rectangular Kaiser)
    end

    private

    def arg_channel(channel)
      cmd_arg = ''
      unless channel.blank?
        channel_number = channel.to_i
        if channel_number < 1
          # mix down to mono
=begin
            Where a range of channels is specified, the channel numbers to the left and right of the hyphen are
            optional and default to 1 and to the number of input channels respectively. Thus
            sox input.wav output.wav remix −
            performs a mix-down of all input channels to mono.
=end
          cmd_arg = 'remix -'
        else
          # select the channel (0 indicates silent channel)
          cmd_arg = "remix #{channel_number}"
        end
      end
      cmd_arg
    end

    def arg_sample_rate(sample_rate)
      cmd_arg = ''
      unless sample_rate.blank?
        # resample quality: medium (m), high (h), veryhigh (v)
        # -s steep filter (band-width = 99%)
        # -a allow aliasing/imaging above the pass-band
        cmd_arg = "rate -v -s -a #{sample_rate}"
      end
      cmd_arg
    end

    def arg_offsets(start_offset, end_offset)
      cmd_arg = ''

      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += "trim #{start_offset_formatted}"
      end

      unless end_offset.blank?
        end_offset_formatted = Time.at(end_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        if start_offset.blank?
          # if start offset was not included, include audio from the start of the file.
          cmd_arg += "trim 0 #{end_offset_formatted}"
        else
          cmd_arg += " =#{end_offset_formatted}"
        end
      end

      cmd_arg
    end

    def arg_window(window)
      cmd_arg = ''
      all_window_options = window_options.join(', ')

      unless window.blank?
        window_param = window.to_i
        raise ArgumentError, "Window size must be one of '#{all_window_options}', given '#{window_param}'." unless window_options.include? window_param

        # window size must be one more than a power of two, see sox documentation http://sox.sourceforge.net/sox.html
        window_param = (window_param / 2) + 1
        cmd_arg = '-y '+window_param.to_s
      end

      cmd_arg
    end

    def arg_window_function(window_function)
      cmd_arg = ''
      all_window_function_options = window_function_options.join(', ')

      unless window_function.blank?

        window_function_param = window_function.to_s
        unless window_function_options.map { |wf| wf.downcase }.include? window_function_param.downcase
          raise ArgumentError, "Window function must be one of '#{all_window_function_options}', given '#{window_function_param}'."
        end

        cmd_arg = '-w '+window_function_param
      end

      cmd_arg
    end

    def arg_colour(colour)
      cmd_arg = ''
      colours_available = colour_options.map { |k, v| "#{k} (#{v})" }.join(', ')
      colour_param = ''

      unless colour.blank?
        colour_param = colour.to_s
        raise ArgumentError, "Colour must be one of '#{colours_available}', given '#{}'." unless colour_options.include? colour_param.to_sym
      end

      default = '-m -q 249 -z 100'
      case colour_param
        when 'g'
          default
        else
          default
      end
    end

  end
end