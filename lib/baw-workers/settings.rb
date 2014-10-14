require 'settingslogic'

module BawWorkers
  # Provides access to settings from yaml file.
  class Settings < Settingslogic
    #namespace 'settings'

    # get access to the logger
    # @return [Logger]
    def logger
      # requires Settings 'Settings.paths.workers_log_file' value to be available
      if !defined?(@stored_logger) || @stored_logger.blank?
        @stored_logger = Logger.new(BawWorkers::Settings.paths.workers_log_file)
        @stored_logger.formatter = BawAudioTools::CustomFormatter.new
        @stored_logger.level = Logger::DEBUG
      end
      @stored_logger
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

    def self.set_mailer_config
      action_mailer = ActionMailer::Base

      action_mailer.logger = Logger.new(STDOUT)
      action_mailer.logger.level = Logger::DEBUG

      action_mailer.raise_delivery_errors = true
      action_mailer.perform_deliveries = true
      action_mailer.delivery_method = :smtp
      action_mailer.smtp_settings =
          {
              address: BawWorkers::Settings.smtp.address
          }
      action_mailer.smtp_settings[:port] = BawWorkers::Settings.smtp.port unless BawWorkers::Settings.smtp.port.blank?

      action_mailer.view_paths = [
          File.expand_path(File.join(File.dirname(__FILE__), 'mail'))
      ]
    end

    def self.audio_helper
      @audio_helper ||= BawAudioTools::AudioBase.from_executables(
          Settings.audio_tools.ffmpeg_executable,
          Settings.audio_tools.ffprobe_executable,
          Settings.audio_tools.mp3splt_executable,
          Settings.audio_tools.sox_executable,
          Settings.audio_tools.wavpack_executable,
          Settings.cached_audio_defaults,
          Settings.paths.temp_dir)
    end

    def self.spectrogram_helper
      @spectrogram_helper ||= BawAudioTools::Spectrogram.from_executables(
          BawWorkers::Settings.audio_helper,
          Settings.audio_tools.imagemagick_convert_executable,
          Settings.audio_tools.imagemagick_identify_executable,
          Settings.cached_spectrogram_defaults,
          Settings.paths.temp_dir)
    end



    def self.original_audio_helper
      @original_audio_helper ||= BawWorkers::Storage::AudioOriginal.new(Settings.paths.original_audios)
    end

    def self.audio_cache_helper
      @audio_cache_helper ||= BawWorkers::Storage::AudioCache.new(Settings.paths.cached_audios)
    end

    def self.spectrogram_cache_helper
      @spectrogram_cache_helper ||= BawWorkers::Storage::SpectrogramCache.new(Settings.paths.cached_spectrograms)
    end

    def self.dataset_cache_helper
      @dataset_cache_helper ||= BawWorkers::Storage::DatasetCache.new(Settings.paths.cached_datasets)
    end

    def self.analysis_cache_helper
      @spectrogram_cache_helper ||= BawWorkers::Storage::AnalysisCache.new(Settings.paths.cached_analysis_jobs)
    end

  end
end
