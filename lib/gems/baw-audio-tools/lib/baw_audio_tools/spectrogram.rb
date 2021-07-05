# frozen_string_literal: true

module BawAudioTools
  # Generate spectrograms (or Waveforms) with SoX (or ffmpeg)
  class Spectrogram
    attr_reader :audio_base, :image_image_magick, :temp_dir

    def initialize(audio_base, image_image_magick, spectrogram_defaults, temp_dir)
      @audio_base = audio_base
      @image_image_magick = image_image_magick
      @spectrogram_defaults = spectrogram_defaults
      @temp_dir = temp_dir
    end

    def self.from_executables(audio_master, im_convert_exe, im_identify_exe, spectrogram_defaults, temp_dir)
      image_image_magick = ImageImageMagick.new(im_convert_exe, im_identify_exe, temp_dir)

      Spectrogram.new(audio_master, image_image_magick, spectrogram_defaults, temp_dir)
    end

    def info(source)
      source = Pathname(source)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless source.exist?
      raise Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if source.zero?

      im_info_cmd = @image_image_magick.info_command(source)
      im_info_output = @audio_base.execute(im_info_cmd)
      im_info = @image_image_magick.parse_info_output(im_info_output[:stdout])

      im_info[:data_length_bytes] = File.size(source)
      im_info[:media_type] = "image/#{im_info[:media_type].downcase}"
      im_info[:height] = im_info[:height].to_i
      im_info[:width] = im_info[:width].to_i

      im_info
    end

    # Creates a new image file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options for modify_parameters:
    # :start_offset :end_offset :channel :sample_rate :window :colour :format
    def modify(source, target, modify_parameters = {})
      source = Pathname(source)
      target = Pathname(target)
      raise ArgumentError, "Source is not a wav file: : #{source}" unless source.extname == '.wav'
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.extname == '.png'
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless source.exist?
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if target.exist?
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      source_info = audio_base.info(source)
      audio_base.check_offsets(source_info, @spectrogram_defaults.min_duration_seconds,
                               @spectrogram_defaults.max_duration_seconds, modify_parameters)

      # spectrogram parameters
      start_offset = modify_parameters.include?(:start_offset) ? modify_parameters[:start_offset] : nil
      end_offset = modify_parameters.include?(:end_offset) ? modify_parameters[:end_offset] : nil
      channel = modify_parameters.include?(:channel) ? modify_parameters[:channel] : nil
      sample_rate = modify_parameters.include?(:sample_rate) ? modify_parameters[:sample_rate] : nil
      window = modify_parameters.include?(:window) ? modify_parameters[:window] : nil
      window_function = modify_parameters.include?(:window_function) ? modify_parameters[:window_function] : @spectrogram_defaults.window_function
      colour = modify_parameters.include?(:colour) ? modify_parameters[:colour] : nil
      #format = modify_parameters.include?(:format) ? modify_parameters[:format] : @defaults.format

      # waveform parameters
      width = modify_parameters.include?(:width) ? modify_parameters[:width] : 1292
      height = modify_parameters.include?(:height) ? modify_parameters[:height] : 256

      if ['w', 'waveform'].include?(colour.to_s.downcase)
        # first create temp wav file using
        # start_offset, end_offset, channel, sample_rate
        temp_wav_file = @audio_base.temp_file('wav')
        @audio_base.modify(source, temp_wav_file, {
          start_offset: start_offset,
          end_offset: end_offset,
          channel: channel,
          sample_rate: sample_rate
        })

        # create waveform with ffmpeg
        cmd = @audio_base.audio_waveform.command(
          temp_wav_file, source_info, target,
          width: width, height: height
        )

      else
        # create spectrogram with sox
        cmd =
          @audio_base.audio_sox.spectrogram_command(
            source, source_info, target, start_offset, end_offset, channel, sample_rate, window, window_function, colour
          )

        @audio_base.execute(cmd)
        @audio_base.check_target(target)

        # remove dc offset using image magick
        cmd = @image_image_magick.modify_command(target, target)
      end
      @audio_base.execute(cmd)
      @audio_base.check_target(target)
    end
  end
end
