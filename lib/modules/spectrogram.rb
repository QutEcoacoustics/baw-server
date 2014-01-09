require 'open3'
require File.dirname(__FILE__) + '/OS'

module Spectrogram
  include OS

  @sox_path = if OS.windows? then "./vendor/bin/sox/sox.exe" else "sox" end
  @image_magick_path = if OS.windows? then './vendor/bin/imagemagick/convert.exe' else 'convert' end
  @sox_arguments_spectrogram = "spectrogram -m -r -l -a -q 249 -w hann -y 257 -X 43.06640625 -z 100"
  @sox_arguments_output = "-o"

  def self.colour_options()
    { :g => :greyscale }
  end

  def self.window_options()
    [ 128, 256, 512, 1024, 2048, 4096 ]
  end

  # Generate a spectrogram image from an audio file.
  # The spectrogram will be 257 pixels high, but the length is not known exactly beforehand.
  # The spectrogram will be created for the entire file. Durations longer than 2 minutes are not recommended.
  # Source is the audio file, target is the image file that will be created.
  # An existing image file will not be overwritten.
  # possible parameters: :window :colour :format
  def self.generate(source, target, modify_parameters)
    raise ArgumentError, "Target path for spectrogram generation already exists: #{target}." unless !File.exist?(target)

    # sample rate
    sample_rate_param = modify_parameters.include?(:sample_rate) ? modify_parameters[:sample_rate].to_i : 11025

    # window size
    all_window_options = window_options.join(', ')
    window_param = modify_parameters.include?(:window) ? modify_parameters[:window].to_i : 512
    raise ArgumentError, "Window size must be one of '#{all_window_options}', given '#{window_param}'." unless window_options.include? window_param

    # window size must be one more than a power of two, see sox documentation http://sox.sourceforge.net/sox.html
    window_param = (window_param / 2) + 1
    window_settings = ' -y '+window_param.to_s

    # colours
    colours_available = colour_options.map { |k, v| "#{k} (#{v})" }.join(', ')
    colour_param = modify_parameters.include?(:colour) ? modify_parameters[:colour] : 'g'
    raise ArgumentError, "Colour must be one of '#{colours_available}', given '#{}'." unless colour_options.include? colour_param.to_sym
    colour_settings = ' -m -q 249 -z 100'


    # sox command to create a spectrogram from an audio file
    # -V is for verbose
    # -n indicates no output audio file
    spectrogram_settings = 'spectrogram -r -l -a -w Hamming -X 43.06640625' + colour_settings + window_settings
    command = "#{@sox_path} -V \"#{source}\" -n rate #{sample_rate_param} #{spectrogram_settings}  #{@sox_arguments_output} \"#{target}\""

    # run the command and wait for the result
    stdout_str, stderr_str, status = Open3.capture3(command)

    # log the command
    Rails.logger.debug "Spectrogram generation return status #{status.exitstatus}. Command: #{command}"

    # check for source file problems
    raise ArgumentError, "Source file was not a valid audio file: #{source}." if stderr_str.include? 'FAIL formats: can\'t open input file'

    # package up all the available information and return it
    result = [ stdout_str, stderr_str, status, source, File.exist?(source), target, File.exist?(target) ]

    # modify the result file to match expected image (remove DC value, size matching ppms of 0.045)
    ppms = 0.045
    duration_sec = modify_parameters[:end_offset].to_f - modify_parameters[:start_offset].to_f
    modify_result = modify(target, target, ppms, duration_sec)

    result
  end

  def self.modify(source, target, ppms, duration_sec)
    raise ArgumentError, "Source path for spectrogram modification does not exist: #{source}." unless File.exist?(source)
    # target will probably already exist
    #raise ArgumentError, "Target path for spectrogram modification already exists: #{target}." unless !File.exist?(target)

    # calculate the expected width
    ##width = ppms * (duration_sec * 1000)

    # http://www.imagemagick.org/Usage/resize/#noaspect
    # don't have to use for linux \! apparently
    #resize_ignore_aspect_ratio = if OS.windows? then '!' else '\!' end
    ##resize_ignore_aspect_ratio = '!'

    # chop: http://www.imagemagick.org/Usage/crop/#chop
    # resize: http://www.imagemagick.org/Usage/resize/
    # disable resizing. The client can take care of manipulating the image to suit the client's needs
    ##command = "#{@image_magick_path} \"#{source}\" -gravity South -chop 0x1 -resize #{width}x256#{resize_ignore_aspect_ratio} #{target}"
    command = "#{@image_magick_path} \"#{source}\" -gravity South -chop 0x1 #{target}"

    # run the command and wait for the result
    stdout_str, stderr_str, status = Open3.capture3(command)

    # log the command
    Rails.logger.debug "Spectrogram modification return status #{status.exitstatus}. Command: #{command}"

    # check for source file problems
    raise ArgumentError, "Source file was not found: #{source}." if stderr_str.include? 'unable to open image'
    raise ArgumentError, "Source file was not a valid image file: #{source}." if stderr_str.include? 'no decode delegate for this image format'

    # package up all the available information and return it
    result = [stdout_str, stderr_str, status, source, File.exist?(source), target, File.exist?(target)]
  end
end