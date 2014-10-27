require 'settingslogic'

module BawWorkers
  # Provides access to settings from yaml file.
  class Settings < Settingslogic
    class << self

      # Configure the settings file and namespace.
      # @param [String] settings_file
      # @param [String] namespace
      # @return [void]
      def configure(settings_file, namespace)
        source(settings_file)
        namespace(namespace)
        puts "===> #{name}: '#{namespace}' loaded from #{settings_file}."
      end

      # Merge another settings file and namespace.
      # @param [String] settings_file
      # @param [String] namespace
      # @return [void]
      def instance_merge(settings_file, namespace)
        puts "===> #{name}: '#{namespace}' merged from #{settings_file}."
        env_settings = BawWorkers::Settings.new(settings_file, namespace)
        instance.deep_merge!(env_settings)
      end

    end
  end
end
