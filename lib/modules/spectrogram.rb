require 'open3'
require File.dirname(__FILE__) + '/OS'

module MediaTools
  class Spectrogram

    attr_reader :audio_master, :image_image_magick, :temp_dir

    public

    def initialize(audio_master, image_image_magick, spectrogram_defaults, temp_dir)
      @audio_master = audio_master
      @image_image_magick = image_image_magick
      @defaults = spectrogram_defaults
      @temp_dir = temp_dir
    end

    def self.from_executables(audio_master, image_magick_exe, spectrogram_defaults, temp_dir)
      audio_master = audio_master
      image_image_magick = ImageImageMagick.new(image_magick_exe, temp_dir)

      Spectrogram.new(audio_master, image_image_magick, spectrogram_defaults, temp_dir)
    end

    # Creates a new image file from source path in target path, modified according to the
    # parameters in modify_parameters. Possible options for modify_parameters:
    # :start_offset :end_offset :channel :sample_rate :window :colour :format
    def modify(source, target, modify_parameters = {})
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      source_info = audio_master.info(source)
      audio_master.check_offsets(source_info, modify_parameters)

      start_offset = modify_parameters.include?(:start_offset) ? modify_parameters[:start_offset] : nil
      end_offset = modify_parameters.include?(:end_offset) ? modify_parameters[:end_offset] : nil
      channel = modify_parameters.include?(:channel) ? modify_parameters[:channel] : @defaults.channel
      sample_rate = modify_parameters.include?(:sample_rate) ? modify_parameters[:sample_rate] : @defaults.sample_rate
      window = modify_parameters.include?(:window) ? modify_parameters[:window] : @defaults.window
      colour = modify_parameters.include?(:colour) ? modify_parameters[:colour] : @defaults.colour
      #format = modify_parameters.include?(:format) ? modify_parameters[:format] : @defaults.format

      # create spectrogram with sox
      cmd =
          @audio_master.audio_sox.spectrogram_command(
              source, source_info, target, start_offset, end_offset, channel, sample_rate, window, colour)

      @audio_master.execute(cmd)
      @audio_master.check_target(target)

      # remove dc offset using image magick
      cmd = @image_image_magick.modify_command(target, target, source_info[:duration_seconds], @defaults.ppms)
      @audio_master.execute(cmd)
      @audio_master.check_target(target)
    end
  end
end