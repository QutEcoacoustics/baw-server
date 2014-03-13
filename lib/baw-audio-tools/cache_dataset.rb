require File.dirname(__FILE__) + '/string'

module BawAudioTools
  class CacheDataset

    attr_reader :storage_paths

    public

    def initialize(storage_paths)
      # array of top-level folder paths to store cached datasets
      @storage_paths = storage_paths

      @separator = '_'
      @extension_indicator = '.'
    end

    def file_name(saved_search_id, dataset_id, format)
      result = saved_search_id.to_s + @separator + dataset_id.to_s + @extension_indicator + format.trim('.', '').to_s
      result.downcase
    end

    def partial_path(file_name)
      # no sub folders
      ''
    end

  end
end
