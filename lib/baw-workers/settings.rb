require 'settingslogic'
# Provides access to settings from yaml file.
module BawWorkers
  class BawWorkers::Settings < Settingslogic
    namespace 'settings'

    # Create or return an existing BawAudioTools::MediaCacher.
    # @return [BawAudioTools::MediaCacher]
    def media_cache_tool
      @media_cache_tool ||= BawAudioTools::MediaCacher.new(BawWorkers::Settings.paths.temp_files)
    end

    def self.set_source(settings_file)
      puts "===> Using settings file #{settings_file}"
      BawWorkers::Settings.source(settings_file)
    end
  end
end
