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

    def check_for_errors(execute_msg)
      stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]
      if !stderr.blank? && stderr.include?(ERROR_UNABLE_TO_OPEN)
        fail Exceptions::FileCorruptError, "Image magick could not open the file.\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && stderr.include?(ERROR_IMAGE_FORMAT)
        fail Exceptions::NotAnImageFileError, "Image magick was given a non-image file.\n\t#{execute_msg[:execute_msg]}"
      end
    end

    def modify_command(source, target)
      fail ArgumentError, "Source is not a png file: #{source}" unless source.match(/\.png/)
      fail ArgumentError, "Target is not a png file: : #{target}" unless target.match(/\.png/)
      fail Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      # target will probably already exist, coz we're overwriting the image
      #fail Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      #fail ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_remove_dc_value = arg_remove_dc_value

      "#{@image_magick_convert_exe} -quiet \"#{source}\" #{cmd_remove_dc_value} \"#{target}\""
    end

    def arg_remove_dc_value
      # chop: http://www.imagemagick.org/Usage/crop/#chop
      '-gravity South -chop 0x1'
    end

  end
end