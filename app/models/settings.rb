require 'settingslogic'
require 'baw-audio-tools'

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

  def media_cache_tool
    @media_cache_tool ||= BawAudioTools::MediaCacher.new(Settings.paths.temp_files)
  end

  def range_request
    @range_request ||= RangeRequest.new
  end

  def version_info
    # see http://semver.org/
    # see http://nvie.com/posts/a-successful-git-branching-model/
    {
        major: 0,
        minor: 10,
        patch: 0,
        pre: '',
        build: ''
    }
  end

  def version_string
    version = "#{version_info[:major]}.#{version_info[:minor]}.#{version_info[:patch]}"

    unless version_info[:pre].blank?
      version += "-#{version_info[:pre]}"
    end

    unless version_info[:build].blank?
      version += "+#{version_info[:build]}"
    end

    version
  end

  def validate
    # check that audio_recording_max_overlap_sec < audio_recording_min_duration_sec
    if Settings.audio_recording_max_overlap_sec >= Settings.audio_recording_min_duration_sec
      raise ArgumentError, "Maximum overlap and trim duration (#{Settings.audio_recording_max_overlap_sec}) "+
          "must be less than minimum audio recording duration (#{Settings.audio_recording_min_duration_sec})."
    end
    puts '===> Configuration passed validation.'
  end

end