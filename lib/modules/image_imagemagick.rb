module MediaTools
  class ImageImageMagick

    ERROR_UNABLE_TO_OPEN = 'unable to open image'
    ERROR_IMAGE_FORMAT = 'no decode delegate for this image format'

    def initialize(image_magick_exe, temp_dir)
      @image_magick_executable = image_magick_exe
      @temp_dir = temp_dir
    end

    def check_for_errors(stdout, stderr)
      raise Exceptions::FileNotFoundError if !stderr.blank? && stderr.include?(ERROR_UNABLE_TO_OPEN)
      raise Exceptions::NotAnImageFileError if !stderr.blank? && stderr.include?(ERROR_IMAGE_FORMAT)
    end

    def modify_command(source, target, duration_sec, ppms)
      raise ArgumentError, "Source is not a png file: #{source}" unless source.match(/\.png/)
      raise ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      # target will probably already exist, coz we're overwriting the image
      #raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      #raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      # disable resizing. The client can take care of manipulating the image to suit the client's needs
      ##cmd_width = arg_width(ppms, duration_sec)
      ##command = "#{@image_magick_path} \"#{source}\" -gravity South -chop 0x1 #{cmd_width} #{target}"

      cmd_remove_dc_value = arg_remove_dc_value

      # chop: http://www.imagemagick.org/Usage/crop/#chop
      "#{@image_magick_path} \"#{source}\" #{cmd_remove_dc_value} #{target}"
    end

    def arg_width(ppms, duration_sec)
      # calculate the expected width
      width = ppms * (duration_sec * 1000)

      # http://www.imagemagick.org/Usage/resize/#noaspect
      # don't have to use for linux \! apparently
      #resize_ignore_aspect_ratio = if OS.windows? then '!' else '\!' end
      resize_ignore_aspect_ratio = '!'

      # resize: http://www.imagemagick.org/Usage/resize/
      "-resize #{width}x256#{resize_ignore_aspect_ratio}"
    end

    def arg_remove_dc_value
      '-gravity South -chop 0x1'
    end

  end
end