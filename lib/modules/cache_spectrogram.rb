module CacheTools
  class CacheSpectrogram

    attr_reader :storage_paths, :defaults

    public

    def initialize(storage_paths, defaults)
      # array of top-level folder paths to store cached spectrograms
      @storage_paths = storage_paths
      # hash of defaults
      @defaults = defaults

      @default_format = 'png'
      @separator = '_'
      @extension_indicator = '.'
    end

    def file_name(uuid, end_offset, start_offset = 0, channel = @defaults[@default_format]['channel'],
        sample_rate = @defaults[@default_format]['sample_rate'], window = @defaults[@default_format]['window'],
        colour = @defaults[@default_format]['colour'], format = @default_format)

      result = uuid.to_s + @separator +
          start_offset.to_f.to_s + @separator + end_offset.to_f.to_s + @separator +
          channel.to_i.to_s + @separator + sample_rate.to_i.to_s + @separator +
          window.to_i.to_s + @separator + colour.to_s +
          @extension_indicator + format.trim('.', '').to_s

      result.downcase
    end


    def partial_path(file_name)
      # prepend first two chars of uuid
      # assume that the file name starts with the uuid, get the first two chars as the sub folder
      file_name[0, 2].downcase
    end

  end
end