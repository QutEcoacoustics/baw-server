require 'settingslogic'

# Using SettingsLogic, see https://github.com/binarylogic/settingslogic
# settings loaded in model/settings.rb
# Accessible through Settings.key
# Environment specific settings expected in config/settings/{environment_name}.yml

class Settings < Settingslogic
  source "#{Rails.root}/config/settings/default.yml"
  namespace Rails.env

  # allow environment specific settings in separate yml files:
  if File.exist?("#{Rails.root}/config/settings/#{Rails.env}.yml")
    puts "===> #{Rails.root}/config/settings/#{Rails.env}.yml loaded."
    instance.deep_merge!(Settings.new("#{Rails.root}/config/settings/#{Rails.env}.yml"))
  else
    puts "===> #{Rails.root}/config/settings/#{Rails.env}.yml not found."
  end

  def cache_tool
    @cache_tool ||= CacheBase.from_paths_audio(
        Settings.paths.original_audios, Settings.paths.cached_audios, Settings.cached_audio_defaults)
  end

end