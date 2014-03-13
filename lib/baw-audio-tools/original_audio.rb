require File.dirname(__FILE__) + '/string'

module BawAudioTools
  class OriginalAudio

    attr_reader :storage_paths

    public

    def initialize(storage_paths)
      # array of top-level folder paths to store original audio
      @storage_paths = storage_paths

      @separator = '_'
      @separator_dash = '-'
      @extension_indicator = '.'
      @date_format = '%y%m%d'
      @time_format = '%H%M'
    end

    # offer option of providing hash instead of method arguments?
    def file_name(uuid, date, time, original_format)
      result = uuid.to_s + @separator

      if date.respond_to?(:strftime)
        result += date.strftime @date_format
      else
        result += date.to_s
      end

      result += @separator_dash

      if time.respond_to?(:strftime)
        result += time.strftime @time_format
      else
        result += time.to_s
      end

      result += @extension_indicator + original_format.trim('.', '').to_s
      result.downcase
    end

    def partial_path(file_name)
      # prepend first two chars of uuid
      # assume that the file name starts with the uuid, get the first two chars as the sub folder
      file_name[0, 2].downcase
    end

  end
end