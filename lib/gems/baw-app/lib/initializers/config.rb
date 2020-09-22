# frozen_string_literal: true

class BawConfigContract < Dry::Validation::Contract
  # TODO: add more validation
  schema do
    required(:audio_recording_max_overlap_sec).value(:float)
    required(:audio_recording_min_duration_sec).value(:float)

    required(:upload_service).hash do
      required(:host).filled(:string)
      required(:port).value(:integer, gt?: 0)
      required(:username).filled(:string)
      required(:password).filled(:string)
    end
  end

  rule(:audio_recording_max_overlap_sec, :audio_recording_min_duration_sec) do
    invalid = values[:audio_recording_max_overlap_sec] >= values[:audio_recording_min_duration_sec]
    if invalid
      message = "Maximum overlap and trim duration (#{values[:audio_recording_max_overlap_sec]}) " \
                "must be less than minimum audio recording duration (#{values[:audio_recording_min_duration_sec]})."
      key.failure(message)
    end
  end
end

module ConfigExtensions
  # override the default settings locations
  def setting_files(config_root, env)
    BawApp.config_files(config_root, env)
  end

  def load_files(*files)
    config = super(*files)
    puts "Settings loaded from #{files}"
    config
  end
end
Config.singleton_class.prepend ConfigExtensions

Config.setup do |config|
  # Name of the constant exposing loaded settings
  config.const_name = 'Settings'

  # Raise an error if a setting is not present in the config file
  config.fail_on_missing = true

  # Ability to remove elements of the array set in earlier loaded settings file. For example value: '--'.
  #
  # config.knockout_prefix = nil

  # Overwrite an existing value when merging a `nil` value.
  # When set to `false`, the existing value is retained after merge.
  #
  # config.merge_nil_values = true

  # Overwrite arrays found in previously loaded settings file. When set to `false`, arrays will be merged.
  #
  # config.overwrite_arrays = true

  # Load environment variables from the `ENV` object and override any settings defined in files.
  #
  # config.use_env = false

  # Define ENV variable prefix deciding which variables to load into config.
  #
  # Reading variables from ENV is case-sensitive. If you define lowercase value below, ensure your ENV variables are
  # prefixed in the same way.
  #
  # When not set it defaults to `config.const_name`.
  #
  config.env_prefix = 'BAW_SETTINGS'

  # What string to use as level separator for settings loaded from ENV variables. Default value of '.' works well
  # with Heroku, but you might want to change it for example for '__' to easy override settings from command line, where
  # using dots in variable names might not be allowed (eg. Bash).
  #
  # config.env_separator = '.'

  # Ability to process variables names:
  #   * nil  - no change
  #   * :downcase - convert to lower case
  #
  # config.env_converter = :downcase

  # Parse numeric values as integers instead of strings.
  #
  # config.env_parse_values = true

  # Validate presence and type of specific config values. Check https://github.com/dry-rb/dry-validation for details.
  config.validation_contract = BawConfigContract.new
end
