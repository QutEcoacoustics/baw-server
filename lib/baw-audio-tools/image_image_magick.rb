module BawAudioTools
  class ImageImageMagick

    ERROR_UNABLE_TO_OPEN = 'unable to open image'
    ERROR_IMAGE_FORMAT = 'no decode delegate for this image format'

    def initialize(im_convert_exe, im_identify_exe, temp_dir)
      @image_magick_convert_exe = im_convert_exe
      @image_magick_identify_exe = im_identify_exe
      @temp_dir = temp_dir
    end

    def info_command(source)
      cmd_format = '"width:%[fx:w]|||height:%[fx:h]|||media_type:%m"'
      "#{@image_magick_identify_exe} -quiet -regard-warnings -ping -format #{cmd_format} \"#{source}\""
    end

    def parse_info_output(output)
      # contains key value output (separate on first colon(:))
      result = {}
      output.strip.split(/\|\|\|/).each { |line|
        if line.include?(':')
          colon_index = line.index(':')
          new_value = line[colon_index+1, line.length].strip
          new_key = line[0, colon_index].strip
          result[new_key.to_sym] = new_value
        end
      }

      result
    end

    def check_for_errors(stdout, stderr)
      if !stderr.blank? && stderr.include?(ERROR_UNABLE_TO_OPEN)
        fail Exceptions::FileCorruptError, "Image magick could not open the file.\n\t Standard output: #{stdout}\n\t Standard Error: #{stderr}"
      end
      if !stderr.blank? && stderr.include?(ERROR_IMAGE_FORMAT)
        fail Exceptions::NotAnImageFileError, "Image magick was given a non-image file.\n\t Standard output: #{stdout}\n\t Standard Error: #{stderr}"
      end
    end

    def modify_command(source, target, duration_sec, ppms)
      fail ArgumentError, "Source is not a png file: #{source}" unless source.match(/\.png/)
      fail ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      fail Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      # target will probably already exist, coz we're overwriting the image
      #fail Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      #fail ArgumentError "Source and Target are the same file: #{target}" unless source != target

      # disable resizing. The client can take care of manipulating the image to suit the client's needs
      ##cmd_width = arg_width(ppms, duration_sec)
      ##command = "#{@image_magick_path} \"#{source}\" -gravity South -chop 0x1 #{cmd_width} #{target}"

      cmd_remove_dc_value = arg_remove_dc_value

      "#{@image_magick_convert_exe} -quiet \"#{source}\" #{cmd_remove_dc_value} \"#{target}\""
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
      # chop: http://www.imagemagick.org/Usage/crop/#chop
      '-gravity South -chop 0x1'
    end

  end
end