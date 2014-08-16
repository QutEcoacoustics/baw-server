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

  # Create or return an existing BawAudioTools::MediaCacher.
  # @return [BawAudioTools::MediaCacher]
  def media_cache_tool
    @media_cache_tool ||= BawAudioTools::MediaCacher.new(Settings.paths.temp_files)
  end

  # Create or return an existing RangeRequest.
  # @return [RangeRequest]
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

  # Get the supported media types.
  # @return [Hash]
  def supported_media_types
    if @media_types.blank?
      @media_types = {}

      Settings.available_formats.each do |key, value|
        media_category = key.to_sym
        @media_types[media_category] = []

        value.each do |media_type|
          ext = NameyWamey.trim(media_type.downcase, '.', '')
          mime_type = Mime::Type.lookup_by_extension(ext)
          @media_types[media_category].push mime_type unless mime_type.blank?
        end
        @media_types[media_category].sort { |a, b| a.to_s <=> b.to_s }
      end
    end

    @media_types
  end

  def is_supported_text_media?(requested_format)
    supported_media_types[:text].include?(requested_format)
  end

  def is_supported_audio_media?(requested_format)
    supported_media_types[:audio].include?(requested_format)
  end

  def is_supported_image_media?(requested_format)
    supported_media_types[:image].include?(requested_format)
  end

  def media_category(requested_format)
    if is_supported_text_media?(requested_format)
      [:text, {}]
    elsif is_supported_audio_media?(requested_format)
      [:audio, Settings.cached_audio_defaults]
    elsif is_supported_image_media?(requested_format)
      [:image, Settings.cached_spectrogram_defaults]
    else
      [:unknown, {}]
    end
  end

  MEDIA_PROCESSOR_LOCAL = 'local'
  MEDIA_PROCESSOR_RESQUE = 'resque'

  def process_media_locally?
    Settings.media_request_processor == MEDIA_PROCESSOR_LOCAL
  end

  def process_media_resque?
    Settings.media_request_processor == MEDIA_PROCESSOR_RESQUE
  end

  def min_duration_larger_overlap?
    Settings.audio_recording_max_overlap_sec >= Settings.audio_recording_min_duration_sec
  end

  def validate
    # check that audio_recording_max_overlap_sec < audio_recording_min_duration_sec
    if min_duration_larger_overlap?
      raise ArgumentError, "Maximum overlap and trim duration (#{Settings.audio_recording_max_overlap_sec}) "+
          "must be less than minimum audio recording duration (#{Settings.audio_recording_min_duration_sec})."
    end
    puts '===> Configuration passed validation.'
  end

end