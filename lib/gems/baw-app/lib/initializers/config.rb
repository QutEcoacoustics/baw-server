# frozen_string_literal: true

require_relative '../types'
# used by resque-scheduler to do cron string parsing
require 'fugit'

# The schema for our Settings files
class BawConfigContract < Dry::Validation::Contract
  ActionsConfigSchema = Dry::Schema.define {
    config.validate_keys = true

    required(:actions).hash do
      required(:active_storage).hash do
        required(:queue).filled(:string)
      end

      required(:active_job_default).hash do
        required(:queue).filled(:string)
      end

      required(:media).hash do
        required(:queue).filled(:string)
        required(:cache_to_redis).filled(:bool)
      end

      required(:harvest).hash do
        required(:queue).filled(:string)
        required(:to_do_path).filled(
          BawApp::Types::CreatedDirPathname
        )
      end

      required(:harvest_scan).hash do
        required(:queue).filled(:string)
      end

      required(:harvest_delete).hash do
        required(:queue).filled(:string)
        required(:delete_after).filled(:integer, gt?: 0)
      end

      required(:analysis_cancel_items).hash do
        required(:queue).filled(:string)
      end

      required(:analysis_remote_enqueue).hash do
        required(:queue).filled(:string)
        required(:schedule).filled(:string)
      end

      required(:analysis_stale_check).hash do
        required(:queue).filled(:string)
        required(:schedule).filled(:string)
        required(:min_age_seconds).filled(:integer, gt?: 0)
      end

      required(:analysis_status_check).hash do
        required(:queue).filled(:string)
        required(:schedule).filled(:string)
      end

      required(:analysis_import_results).hash do
        required(:queue).filled(:string)
      end

      required(:analysis_amend_after_harvest).hash do
        required(:queue).filled(:string)
      end
    end
  }

  SftpgoConfigSchema = Dry::Schema.define {
    required(:upload_service).hash do
      required(:admin_host).filled(:string)
      required(:public_host).filled(:string)
      required(:port).value(:integer, gt?: 0)
      required(:username).filled(:string)
      required(:password).filled(:string)
      required(:sftp_port).filled(:integer, gt?: 0)
    end
  }

  InternalConfigSchema = Dry::Schema.define {
    required(:internal).hash do
      required(:allow_list).array(BawApp::Types::IPAddr)
    end
  }

  PathsConfigSchema = Dry::Schema.define {
    required(:paths).hash do
      required(:temp_dir).filled(:string)
      required(:programs_dir).filled(:string)
      required(:cached_spectrograms).array(BawApp::Types::CreatedDirPathname)
      required(:cached_audios).array(BawApp::Types::CreatedDirPathname)
      required(:cached_analysis_jobs).array(BawApp::Types::CreatedDirPathname)
      required(:worker_log_file).filled(:string)
      required(:mailer_log_file).filled(:string)
      required(:audio_tools_log_file).filled(:string)
      required(:temp_dir).filled(:string)
      required(:programs_dir).filled(:string)
    end
  }

  BatchAnalysisSchema = Dry::Schema.define {
    required(:batch_analysis).hash do
      required(:connection).hash do
        required(:host).filled(:string)
        required(:port).value(:integer, gt?: 0)
        required(:username).filled(:string)
        required(:password).maybe(:string)
        required(:key_file).maybe(BawApp::Types::PathExists)
      end
      required(:pbs).hash do
        required(:default_queue).maybe(:string)
        required(:primary_group).filled(:string)
      end
      required(:remote_enqueue_limit).maybe(:integer, gt?: 0)
      required(:auth_tokens_expire_in).filled(:integer, gt?: 0)
      required(:root_data_path_mapping).hash do
        required(:workbench).filled(:string)
        required(:cluster).filled(:string)
      end
    end
  }

  OrganizationNames = Dry::Schema.define {
    required(:organisation_names).hash do
      required(:site_short_name).filled(:string)
      required(:site_long_name).filled(:string)
      required(:organisation_name).filled(:string)
      required(:github_issues_url).filled(:string)
      required(:address).filled(:string)
    end
  }

  AudioEventFileImport = Dry::Schema.define {
    required(:audio_event_imports).hash do
      required(:max_file_size_bytes).filled(:integer, gteq?: 0)
      required(:acceptable_content_types).array(:string)
    end
  }

  DEPRECATIONS = [
    :api,
    :endpoints
  ].freeze

  # TODO: add more validation
  # Note: ruby config does not make use of values that may have been coerced during validation
  # so type conversion is useless.
  # See ../settings_module.rb for an example of how to strongly type settings.
  schema(
    ActionsConfigSchema,
    SftpgoConfigSchema,
    InternalConfigSchema,
    PathsConfigSchema,
    BatchAnalysisSchema,
    OrganizationNames,
    AudioEventFileImport
  ) do
    required(:trusted_proxies).array(BawApp::Types::IPAddr)

    required(:audio_recording_max_overlap_sec).value(:float)
    required(:audio_recording_min_duration_sec).value(:float)

    required(:logs).hash do
      required(:tag).maybe(:string)
      required(:directory).filled(:string)
    end

    required(:resque).hash do
      required(:connection).hash
      required(:namespace).filled(:string)
      required(:log_level).filled(BawApp::Types::LogLevel)
      required(:polling_interval_seconds).filled(BawApp::Types::Coercible::Float)
    end

    required(:resque_scheduler).hash do
      required(:polling_interval_seconds).filled(BawApp::Types::Coercible::Float)
      required(:log_level).filled(BawApp::Types::LogLevel)
    end

    # deprecations (validated below)
    DEPRECATIONS.each do |key|
      optional(key)
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

  rule(actions: { analysis_remote_enqueue: :schedule }) do
    # parse the cron string to check it is valid in the same way that
    # resque-scheduler does.

    next if Fugit.parse_cron(value)

    # will raise on failure
    key.failure("Could not parse cron schedule for value '#{value}'. Supported values are defined at https://github.com/floraison/fugit/#fugitcron")
  end

  # deprecations
  DEPRECATIONS.each do |deprecation|
    rule(deprecation) do
      next if value.nil?

      key.failure('is deprecated, please remove this settings section')
    end
  end
end

module ConfigExtensions
  # override the default settings locations
  def setting_files(config_root, env)
    BawApp.config_files(config_root, env)
  end
end
Config.singleton_class.prepend ConfigExtensions

require "#{__dir__}/../settings_module.rb"
Config::Options.prepend(BawApp::SettingsModule)

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
