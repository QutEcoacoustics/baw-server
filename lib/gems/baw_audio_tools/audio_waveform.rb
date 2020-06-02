# frozen_string_literal: true

module BawAudioTools
  # deprecated: no longer supported
  class AudioWaveform
    def initialize(wav2png_executable, temp_dir)
      @wav2png_executable = wav2png_executable
      @temp_dir = temp_dir
    end

    def command(source, _source_info, target,
                width = 1800, height = 280,
                colour_bg = 'efefefff', colour_fg = '00000000',
                scale = :linear,
                db_min = -48, db_max = 0)

      # Too hard to maintain, wav2png is hard to install, feature never used.
      # If we want this to work then ffmpeg has a `showwavespic` command.
      raise NotImplementedError, 'Drawing waveforms has been deprecated and is no longer supported'

      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.file? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.file? target
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_scale = arg_scale(scale)
      cmd_colour_bg = arg_colour_bg(colour_bg)
      cmd_colour_fg = arg_colour_fg(colour_fg)
      cmd_width = arg_width(width)
      cmd_height = arg_height(height)
      cmd_db_min = arg_db_min(db_min)
      cmd_db_max = arg_db_max(db_max)

      "#{@wav2png_executable} #{cmd_scale} #{cmd_colour_bg} #{cmd_colour_fg} " \
        "#{cmd_width} #{cmd_height} #{cmd_db_max} #{cmd_db_min} " \
        "--output \"#{target}\" \"#{source}\""
    end

    def self.scale_options
      [:linear, :logarithmic]
    end

    def arg_scale(scale)
      # -d [ --db-scale ] use logarithmic (e.g. decibel) scale instead of linear scale
      cmd_arg = ''
      all_scale_options = AudioWaveform.scale_options.join(', ')

      unless scale.blank?

        scale_param = scale.to_s
        unless AudioWaveform.scale_options.include? scale_param.to_sym
          raise ArgumentError, "Scale must be one of '#{all_scale_options}', given '#{scale_param}'."
        end

        cmd_arg = scale_param.to_sym == :logarithmic ? '--db-scale' : ''
      end

      cmd_arg
    end

    def arg_colour_bg(value)
      # -b [ --background-color ] arg (=efefefff)  color of background in hex rgba
      arg_hex('Background colour', '--background-color', value)
    end

    def arg_colour_fg(value)
      # -f [ --foreground-color ] arg (=00000000)  color of background in hex rgba
      arg_hex('Foreground colour', '--foreground-color', value)
    end

    def arg_width(value)
      # -w [ --width ] arg (=1800) width of generated image
      arg_number('Width', '--width', value)
    end

    def arg_height(value)
      # -h [ --height ] arg (=280) height of generated image
      arg_number('Height', '--height', value)
    end

    def arg_db_min(value)
      # --db-min arg (=-48) minimum value of the signal in dB, that will be visible in the waveform
      arg_number('Db minimum', '--db-min', value)
    end

    def arg_db_max(value)
      # --db-max arg (=0)  maximum value of the signal in dB, that will be visible in the waveform.
      #Usefull, if you now, that your signal peaks at a certain level.
      arg_number('Db maximum', '--db-max', value)
    end

    private

    def numeric?(value)
      return true if value =~ /\A\d+\Z/

      begin
        true if Float(value)
      rescue StandardError
        false
      end
    end

    def arg_number(name, param_string, value)
      raise ArgumentError, "#{name} must not be blank." if value.blank?
      raise ArgumentError, "#{name} must be a number, given '#{value}'." unless numeric?(value)

      "#{param_string} #{value}"
    end

    def hex_digits?(value)
      !value[/\H/] # if any char is not a hex digit
    end

    def arg_hex(name, param_string, value)
      cmd_arg = ''
      unless value.blank?
        value_param = value.to_s

        if !hex_digits?(value_param) || value_param.length != 8
          raise ArgumentError, "#{name} must be a hexadecimal rgba value, given '#{value_param}'."
        end

        cmd_arg = "#{param_string} #{value_param}"
      end

      cmd_arg
    end
  end
end
