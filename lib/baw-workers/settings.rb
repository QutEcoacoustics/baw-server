require 'settingslogic'

module BawWorkers
  # Provides access to settings from yaml file.
  class BawWorkers::Settings < Settingslogic
    #namespace 'settings'

    # Create or return an existing BawAudioTools::MediaCacher.
    # @return [BawAudioTools::MediaCacher]
    def media_cache_tool
      @media_cache_tool ||= BawAudioTools::MediaCacher.new(BawWorkers::Settings.paths.temp_files)
    end

    # Set the source file.
    # @param [String] settings_file
    # @return [void]
    def self.set_source(settings_file)
      puts "===> baw-workers file #{settings_file} loaded."
      BawWorkers::Settings.source(settings_file)
    end

    # Set the Settings namespace.
    # @param [String] namespace
    # @return [void]
    def self.set_namespace(namespace)
      puts "===> baw-workers namespace set to #{namespace}."
      BawWorkers::Settings.namespace(namespace)
    end

    # Merge another Settings with this one.
    # @param [Settings] settings
    # @return [void]
    def self.instance_merge(settings)
      puts '===> baw-workers merged additional settings.'
      instance.deep_merge!(settings)
    end

  end
end
