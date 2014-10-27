require 'settingslogic'

module BawWorkers
  # Provides access to settings from yaml file.
  class Settings < Settingslogic
    class << self

      def configure(settings_file, namespace)
        source(settings_file)
        namespace(namespace)
        puts "===> #{name}: '#{namespace}' loaded from #{settings_file}."
      end

    end
  end
end
