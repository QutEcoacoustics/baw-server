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
        puts "===> #{settings_class.to_s} file #{settings_file} loaded."
        settings_class.source(settings_file)
      end

      # Set the Settings namespace for a settings class.
      # @param [Class] settings_class
      # @param [String] namespace
      # @return [void]
      def set_namespace(settings_class, namespace)
        puts "===> #{settings_class.to_s} namespace set to #{namespace}."
        settings_class.namespace(namespace)
      end

      # Merge another Settingslogic instance with this Settingslogic instance.
      # @param [Settingslogic] settings_instance
      # @param [Settingslogic] new_settings
      # @return [void]
      def instance_merge(settings_instance, new_settings)
        puts "===> #{settings_instance.class.to_s} merged additional settings."
        settings_instance.deep_merge!(new_settings)
      end

    end
  end
end
