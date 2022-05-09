# frozen_string_literal: true

module BawAudioTools
  # Used to manipulate the SoX command line tool
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

    def parse_info_output(execute_msg)
      # contains key value output (separate on first colon(:))
      result = {}
      execute_msg[:stderr].strip.split(/\r?\n|\r/).each do |line|
        next unless line.include?(':')

        colon_index = line.index(':')
        new_value = line[colon_index + 1, line.length].strip
        new_key = line[0, colon_index].strip
        result[new_key] = new_value
      end

      result
    end

    def check_for_errors(execute_msg)
      stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]
      if !stderr.blank? && stderr.include?(ERROR_CANNOT_OPEN)
        raise Exceptions::FileCorruptError, "sox could not open the file.\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && stderr.include?(ERROR_NO_HANDLER)
        raise Exceptions::AudioToolError, "sox cannot open this file type.\n\t#{execute_msg[:execute_msg]}"
      end
    end

    def modify_command(source, _source_info, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil)
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exist? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exist? target
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_offsets = arg_offsets(start_offset, end_offset)
      sample_rate = arg_sample_rate(sample_rate)
      cmd_channel = arg_channel(channel)

      "#{@sox_executable} -q -V4 \"#{source}\" \"#{target}\" #{cmd_offsets} #{sample_rate} #{cmd_channel}"
    end

    def spectrogram_command(
      source, _source_info, target,
      start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil,
      window = nil, window_function = nil, colour = nil
    )
      source = Pathname(source)
      target = Pathname(target)
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.extname == '.wav'
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.extname == '.png'
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless source.exist?
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if target.exist?
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_offsets = arg_offsets(start_offset, end_offset)
      cmd_sample_rate = arg_sample_rate(sample_rate)
      cmd_channel = arg_channel(channel)
      cmd_window = arg_window(window)
      cmd_window_function = arg_window_function(window_function)
      cmd_colour = arg_colour(colour)
      cmd_pixels_second = arg_pixels_second(sample_rate, window)

      # -X is for native ppms - not 0.045
      # defaults to (22050 / 512) || (11025 / 256) (sample rate / window size)

      # common parameters
      # -r Raw spectrogram: suppress the display of axes and legends.
      # -l Creates a ‘printer friendly’ spectrogram with a light background
      #    (the default has a dark background).
      # -a Suppress the display of the axis lines. This is sometimes
      #    useful in helping to discern artefacts at the spectrogram edges.
      cmd_spectrogram = 'spectrogram -r -l -a'

      # sox command to create a spectrogram from an audio file
      # -V is for verbose
      # -n indicates no output audio file
      "#{@sox_executable} -V \"#{source}\" -n #{cmd_offsets} #{cmd_sample_rate} #{cmd_channel} " \
        "#{cmd_spectrogram} #{cmd_pixels_second} #{cmd_colour} #{cmd_window} #{cmd_window_function} " \
        "-o \"#{target}\""
    end

    def self.window_options
      [128, 256, 512, 1024, 2048, 4096]
    end

    def self.colour_options
      {
        g: :greyscale,
        h: :high_contrast,
        pr: :pink_red,
        tg: :teal_green,
        yg: :yellow_green,
        gr: :green_red,
        tb: :teal_blue,
        rb: :red_blue
      }.freeze
    end

    def self.window_function_options
      # Window: Hann (default), Hamming, Bartlett, Rectangular or Kaiser. The spectrogram is produced using the
      # Discrete Fourier Transform (DFT) algorithm. A significant parameter to this algorithm is the choice of
      # ‘window function’. By default, SoX uses the Hann window which has good all-round frequency-resolution
      # and dynamic-range properties. For better frequency resolution (but lower dynamic-range), select a
      # Hamming window; for higher dynamic-range (but poorer frequency-resolution), select a Kaiser window.
      # Bartlett and Rectangular windows are also available.
      ['Hann', 'Hamming', 'Bartlett', 'Rectangular', 'Kaiser']
    end

    private

    def arg_channel(channel)
      cmd_arg = ''
      unless channel.blank?
        channel_number = channel.to_i
        if channel_number < 1
          # mix down to mono
          #             Where a range of channels is specified, the channel numbers to the left and right of the hyphen are
          #             optional and default to 1 and to the number of input channels respectively. Thus
          #             sox input.wav output.wav remix −
          #             performs a mix-down of all input channels to mono.
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
      # Cuts portions out of the audio. Any number of positions may be given; audio is not sent
      # to the output until the first position is reached. The effect then alternates between
      # copying and discarding audio at each position.

      # If a position is preceded by an equals (=) or minus (-) sign, it is interpreted relative to the
      # beginning or the end of the audio, respectively. (The audio length must be known for
      # end-relative locations to work.) Otherwise, it is considered an offset from the last
      # position, or from the start of audio for the first parameter. Using a value of 0 for
      # the first position parameter allows copying from the beginning of the audio.

      # All parameters can be specified using either an amount of time or an exact count of samples.
      # The format for specifying lengths in time is hh:mm:ss.frac. A value of 1:30.5 for the first
      # parameter will not start until 1 minute, thirty and ½ seconds into the audio. The format for
      # specifying sample counts is the number of samples with the letter ‘s’ appended to it.
      # A value of 8000s for the first parameter will wait until 8000 samples are read before
      # starting to process audio.

      cmd_arg = ''

      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += "trim #{start_offset_formatted}"
      end

      unless end_offset.blank?
        end_offset_formatted = Time.at(end_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += if start_offset.blank?
                     # if start offset was not included, include audio from the start of the file.
                     "trim 0 #{end_offset_formatted}"
                   else
                     " =#{end_offset_formatted}"
                   end
      end

      cmd_arg
    end

    def arg_window(window)
      # Sets the Y-axis size in pixels (per channel); this is the number of frequency ‘bins’ used in
      # the Fourier analysis that produces the spectrogram. N.B. it can be slow to produce the
      # spectrogram if this number is not one more than a power of two (e.g. 129). By default
      # the Y-axis size is chosen automatically (depending on the number of channels).
      cmd_arg = ''
      all_window_options = AudioSox.window_options.join(', ')

      unless window.blank?
        window_param = window.to_i
        unless AudioSox.window_options.include? window_param
          raise ArgumentError, "Window size must be one of '#{all_window_options}', given '#{window_param}'."
        end

        # window size must be one more than a power of two, see sox documentation http://sox.sourceforge.net/sox.html
        window_param = (window_param / 2) + 1
        cmd_arg = "-y #{window_param}"
      end

      cmd_arg
    end

    def arg_window_function(window_function)
      # The spectrogram is produced using the Discrete Fourier Transform (DFT) algorithm.
      # A significant parameter to this algorithm is the choice of ‘window function’.
      cmd_arg = ''
      all_window_function_options = AudioSox.window_function_options.join(', ')

      unless window_function.blank?

        window_function_param = window_function.to_s
        unless AudioSox.window_function_options.map { |wf| wf }.include? window_function_param
          raise ArgumentError,
            "Window function must be one of '#{all_window_function_options}', given '#{window_function_param}'."
        end

        cmd_arg = "-w #{window_function_param}"
      end

      cmd_arg
    end

    def colours_available
      AudioSox.colour_options.map { |k, v| "#{k} (#{v})" }.join(', ')
    end

    def arg_colour(colour)
      colour = 'g' if colour.blank?

      # normalize to argument
      case colour.to_s
      when 'g', 'greyscale' then '-m'
      when 'h', 'high_contrast' then '-h'
      when 'pr', 'pink_red' then '-p 1'
      when 'tg', 'teal_green' then '-p 2'
      when 'yg', 'yellow_green' then '-p 3'
      when 'gr', 'green_red' then '-p 4'
      when 'tb', 'teal_blue' then '-p 5'
      when 'rb', 'red_blue' then '-p 6'
      else
        raise ArgumentError, "Colour must be one of '#{colours_available}', given '#{colour}'."
      end => colour_param

      "#{colour_param} -q 249 -z 100"
    end

    def arg_pixels_second(sample_rate, window_size)
      # X-axis pixels/second; the default is auto-calculated to fit the given or known audio
      # duration to the X-axis size, or 100 otherwise. If given in conjunction with −d, this
      # option affects the width of the spectrogram; otherwise, it affects the duration of the
      # spectrogram. num can be from 1 (low time resolution) to 5000 (high time resolution) and
      # need not be an integer. SoX may make a slight adjustment to the given number for
      # processing quantization reasons; if so, SoX will report the actual number used
      # (viewable when the SoX global option −V is in effect). See also −x and −d.
      cmd_arg = ''
      if !sample_rate.blank? && !window_size.blank?
        pixels_per_second = sample_rate.to_f / window_size
        cmd_arg = "-X #{pixels_per_second}"
      end

      cmd_arg
    end
  end
end
