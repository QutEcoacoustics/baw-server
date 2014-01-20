require 'open3'
require File.dirname(__FILE__) + '/string'
require File.dirname(__FILE__) + '/hash'
require File.dirname(__FILE__) + '/exceptions'
require File.dirname(__FILE__) + '/logging'
require File.dirname(__FILE__) + '/OS'
require File.dirname(__FILE__) + '/image_image_magick'


class Spectrogram

  attr_reader :audio_master, :image_image_magick, :temp_dir

  public

  def initialize(audio_master, image_image_magick, spectrogram_defaults, temp_dir)
    @audio_master = audio_master
    @image_image_magick = image_image_magick
    @defaults = spectrogram_defaults
    @temp_dir = temp_dir
  end

  def self.from_executables(audio_master, im_convert_exe, im_identify_exe, spectrogram_defaults, temp_dir)
    audio_master = audio_master
    image_image_magick = ImageImageMagick.new(im_convert_exe, im_identify_exe, temp_dir)

    Spectrogram.new(audio_master, image_image_magick, spectrogram_defaults, temp_dir)
  end

  def info(source)
    raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
    raise Exceptions::FileEmptyError, "Source exists, but has no content: #{source}" if File.size(source) < 1

    im_info_cmd = @image_image_magick.info_command(source)
    im_info_output = @audio_master.execute(im_info_cmd)
    im_info = @image_image_magick.parse_info_output(im_info_output[:stdout])
    im_info[:data_length_bytes] = File.size(source)

    im_info
  end

  # Creates a new image file from source path in target path, modified according to the
  # parameters in modify_parameters. Possible options for modify_parameters:
  # :start_offset :end_offset :channel :sample_rate :window :colour :format
  def modify(source, target, modify_parameters = {})
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

    # convert to wav file with ffmpeg
    temp_file = @audio_master.temp_file('wav')
    cmd = @audio_master.audio_ffmpeg.modify_command(
        source, source_info, temp_file, start_offset, end_offset, channel, sample_rate)

    @audio_master.execute(cmd)
    @audio_master.check_target(temp_file)

    # create spectrogram with sox
    cmd =
        @audio_master.audio_sox.spectrogram_command(
            temp_file, source_info, target, start_offset, end_offset, channel, sample_rate, window, colour)

    @audio_master.execute(cmd)
    File.delete temp_file
    @audio_master.check_target(target)

    # remove dc offset using image magick
    cmd = @image_image_magick.modify_command(target, target, source_info[:duration_seconds], @defaults.ppms)
    @audio_master.execute(cmd)
    @audio_master.check_target(target)
  end
end