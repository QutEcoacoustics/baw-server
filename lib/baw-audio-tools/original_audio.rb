module BawAudioTools
  class OriginalAudio

    attr_reader :storage_paths

    public

    def initialize(storage_paths)
      # array of top-level folder paths to store original audio
      @storage_paths = storage_paths

      @separator = '_'
      @extension_indicator = '.'
    end

    # Create a file name. This file name is by convention always in utc offset +1000.
    # @deprecated
    # @param [string] uuid
    # @param [ActiveSupport::TimeWithZone] datetime
    # @param [string] original_format
    # @return [string] file name
    def file_name(uuid, datetime, original_format)
      result = uuid.to_s + @separator

      if datetime.is_a?(ActiveSupport::TimeWithZone)
        format_string = '%y%m%d-%H%M'
        result += datetime.utc.advance(hours: 10).strftime(format_string)
      else
        raise BawAudioTools::Exceptions::CacheRequestError, "Only uses ActiveSupport::TimeWithZone, given #{uuid}, #{datetime}, #{original_format}."
      end

      result += @extension_indicator + original_format.trim('.', '').to_s
      result.downcase
    end

    # Create a file name. This filename is always explicitly in UTC.
    # @param [string] uuid
    # @param [ActiveSupport::TimeWithZone] datetime
    # @param [string] original_format
    # @return [string] file name
    def file_name_utc(uuid, datetime, original_format)
      result = uuid.to_s + @separator

      if datetime.is_a?(ActiveSupport::TimeWithZone)
        format_string = '%Y%m%d-%H%M%S'
        result += datetime.utc.strftime(format_string).downcase
      else
        raise BawAudioTools::Exceptions::CacheRequestError, "Only uses ActiveSupport::TimeWithZone, given #{uuid}, #{datetime}, #{original_format}."
      end

      result + 'Z' + @extension_indicator + original_format.trim('.', '').to_s.downcase
    end



    def partial_path(file_name)
      # prepend first two chars of uuid
      # assume that the file name starts with the uuid, get the first two chars as the sub folder
      file_name[0, 2].downcase
    end

  end
end