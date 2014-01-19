module CacheTools
  class CacheDataset

    attr_reader :storage_paths, :defaults

    public

    def initialize(storage_paths, defaults)
      # array of top-level folder paths to store cached datasets
      @storage_paths = storage_paths
      # hash of defaults
      @defaults = defaults

      @separator = '_'
      @extension_indicator = '.'
    end

    def file_name(saved_search_id, dataset_id, format = @defaults.format)
      result = saved_search_id.to_s + @separator + dataset_id.to_s + @extension_indicator + format.trim('.', '').to_s
      result.downcase

    end

    def partial_path(file_name)
      # no sub folders
      ''
    end

  end
end