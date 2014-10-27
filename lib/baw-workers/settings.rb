require 'settingslogic'

module BawWorkers
  # Provides access to settings from yaml file.
  class Settings < Settingslogic
    #namespace 'settings'

    class << self

      # Set the settings file for a settings class.
      # @param [Class] settings_class
      # @param [String] settings_file
      # @return [void]
      def set_source(settings_class, settings_file)
        puts "===> #{settings_class.to_s}: loaded file #{settings_file}."
        settings_class.source(settings_file)
      end

      # Set the Settings namespace for a settings class.
      # @param [Class] settings_class
      # @param [String] namespace
      # @return [void]
      def set_namespace(settings_class, namespace)
        puts "===> #{settings_class.to_s}: namespace set to #{namespace}."
        settings_class.namespace(namespace)
      end

      # Merge another settings file..
      # @param [Class] settings_class
      # @param [String] settings_file
      # @param [String] settings_namespace
      # @return [void]
      def instance_merge(settings_class, settings_file, settings_namespace)
        puts "===> #{settings_class.to_s}: merged file #{settings_file}."
        env_settings = Settings.new(settings_file, settings_namespace)
        settings_class.deep_merge!(env_settings)
      end

    end
  end
end
