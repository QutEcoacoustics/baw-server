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

    def self.set_mailer_config
      action_mailer = ActionMailer::Base

      action_mailer.logger = Logger.new(STDOUT)
      action_mailer.logger.level = Logger::DEBUG

      action_mailer.raise_delivery_errors = true
      action_mailer.perform_deliveries = true
      action_mailer.delivery_method = :smtp
      action_mailer.smtp_settings =
          {
              address: Settings.smtp.address
          }
      action_mailer.smtp_settings[:port] = Settings.smtp.port unless Settings.smtp.port.blank?

      action_mailer.view_paths = [
          File.expand_path(File.join(File.dirname(__FILE__), 'mail'))
      ]
    end

  end
end
