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
end