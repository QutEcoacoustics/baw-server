require 'settingslogic'

# Provides access to settings from yaml file.
module BawWorkers
  class BawWorkers::Settings < Settingslogic
    #namespace 'settings'

    # Create or return an existing BawAudioTools::MediaCacher.
    # @return [BawAudioTools::MediaCacher]
    def media_cache_tool
      @media_cache_tool ||= BawAudioTools::MediaCacher.new(BawWorkers::Settings.paths.temp_files)
    end

    def self.set_source(settings_file)
      puts "===> baw-workers file #{settings_file} loaded."
      BawWorkers::Settings.source(settings_file)
    end

    def self.set_namespace(namespace)
      BawWorkers::Settings.namespace(namespace)
    end

    def self.instance_merge(settings)
      instance.deep_merge!(settings)
    end

  end
end
