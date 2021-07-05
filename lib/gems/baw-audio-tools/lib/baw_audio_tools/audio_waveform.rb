# frozen_string_literal: true

module BawAudioTools
  # Generate a waveform
  # https://ffmpeg.org/ffmpeg-filters.html#toc-showwavespic
  class AudioWaveform
    def initialize(ffmpeg_executable, temp_dir)
      raise 'not ffmpeg' unless ffmpeg_executable =~ /ffmpeg/

      @ffmpeg_executable = ffmpeg_executable
      @temp_dir = temp_dir
    end

    def command(
      source, _source_info, target,
      width: 1800, height: 280,
      colour_fg: 'FF9329FF', # audacity dark theme orange
      scale: :lin
    )
      source = Pathname(source)
      target = Pathname(target)

      raise ArgumentError, "Source is not a wav file: #{source}" unless source.extname == '.wav'
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.extname == '.png'
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless source.exist?
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if target.exist?
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_scale = arg_scale(scale)
      cmd_colour_fg = arg_colour(colour_fg)
      cmd_size = arg_size(width, height)

      args = [cmd_scale, cmd_colour_fg, cmd_size].join(':')

      # ffmpeg -i spec/fixtures/files/test-audio-mono.ogg -filter_complex 'showwavespic=colors=#00FFFF' waveform.png -y
      "#{@ffmpeg_executable} -nostdin -i '#{source}'" \
        " -filter_complex 'showwavespic=#{args}'" \
        " '#{target}'"
    end

    def self.scale_options
      [:lin, :log, :sqrt, :chrt]
    end

    def arg_scale(scale)
      scale = :lin if scale.blank?

      scale_param = scale.to_s

      return "scale=#{scale_param}" if self.class.scale_options.include? scale_param.to_sym

      raise ArgumentError, "Scale must be one of '#{self.class.scale_options}', given '#{scale_param}'."
    end

    def arg_colour(value)
      # colors
      # Set colors separated by ’|’ which are going to be used for drawing of each channel.
      arg_hex('colour_fg', 'colors', value)
    end

    def arg_size(width, height)
      # size, s
      # Specify the video size for the output. Default value is 600x240.

      check_number('Width', width)
      check_number('Width', height)
      "size=#{width}x#{height}"
    end

    private

    def integer?(value)
      return true if value =~ /[0-9]+/

      begin
        return true if Integer(value)
      rescue StandardError
        return false
      end

      false
    end

    def check_number(name, value)
      raise ArgumentError, "#{name} must not be blank." if value.blank?
      raise ArgumentError, "#{name} must be a number, given '#{value}'." unless integer?(value)

      value
    end

    def hex_digits?(value)
      !value[/\H/] # if any char is not a hex digit
    end

    def arg_hex(name, param_string, value)
      value = '000000FF' if value.blank?
      value_param = value.to_s

      if !hex_digits?(value_param) || value_param.length != 8
        raise ArgumentError, "#{name} must be a hexadecimal RGBA value, given '#{value_param}'."
      end

      value_param = "##{value_param}" unless value_param.start_with?('#')

      "#{param_string}=#{value_param}"
    end
  end
end
