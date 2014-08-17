require 'settingslogic'

class Settings < Settingslogic
  namespace 'settings'

  # Create or return an existing BawAudioTools::MediaCacher.
  # @return [BawAudioTools::MediaCacher]
  def media_cache_tool
    @media_cache_tool ||= BawAudioTools::MediaCacher.new(Settings.paths.temp_files)
  end

  def self.set_source(settings_file)
    puts "===> Using settings file #{settings_file}"
    Settings.source(settings_file)
  end
end
