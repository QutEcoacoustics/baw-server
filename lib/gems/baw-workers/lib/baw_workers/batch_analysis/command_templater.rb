# frozen_string_literal: true

require 'liquid'

module BawWorkers
  module BatchAnalysis
    # A class that creates a command string from a template and a list of
    # resources.
    # The template is expected  to include placeholders for at least the SOURCE/
    # SOURCE_DIR and OUTPUT tokens.
    #
    # The template uses Liquid placeholders and tags, e.g.
    # `analysis.exe {{ source }} {{ output_dir }}` and
    # `{% if config %}--config {{ config }}{% endif %}`.
    #
    # Multiple substitutions can be made for a single placeholder.
    module CommandTemplater
      # Makes the default formatting of Time objects the ISO8601 format,
      # which is more likely to be useful in command templates.
      # ! This unfortunately is a leaky abstraction
      # but it is not too bad since one could always use a date filter to format the time as desired.
      module LiquidFormatOverrides
        def to_s(obj, seen = {})
          if obj.is_a?(Time)
            obj.iso8601
          else
            super
          end
        end
      end

      ::Liquid::Utils.singleton_class.prepend(LiquidFormatOverrides)

      # a directory containing the source audio file to process
      SOURCE_DIR = :source_dir
      # a directory containing the configuration file to use
      CONFIG_DIR = :config_dir
      # a directory to write output files to
      OUTPUT_DIR = :output_dir
      # a directory to write temporary files to
      TEMP_DIR = :temp_dir
      # the basename of the source audio file
      SOURCE_BASENAME = :source_basename
      # the basename of the configuration file.
      CONFIG_BASENAME = :config_basename
      # the source audio file to process - this is the full path to the file
      SOURCE = :source
      # the configuration file to use - this is the full path to the file
      CONFIG = :config
      # the latitude of the audio recording
      LATITUDE = :latitude
      # the longitude of the audio recording
      LONGITUDE = :longitude
      # the timestamp of the audio recording, ISO8601 format
      TIMESTAMP = :timestamp
      # the id of the audio recording
      ID = :id
      # the uuid of the audio recording
      UUID = :uuid

      ALL = Set.new([
        SOURCE_DIR,
        CONFIG_DIR,
        OUTPUT_DIR,
        TEMP_DIR,
        SOURCE_BASENAME,
        CONFIG_BASENAME,
        SOURCE,
        CONFIG,
        LATITUDE,
        LONGITUDE,
        TIMESTAMP,
        ID,
        UUID
      ]).freeze

      REQUIRED_COMMAND_PLACEHOLDERS = [
        [SOURCE_DIR, SOURCE],
        [OUTPUT_DIR]
      ].freeze

      CONFIG_PLACEHOLDERS = [
        CONFIG_DIR,
        CONFIG_BASENAME,
        CONFIG
      ].freeze

      # Template a command string with the given values.
      # @param command [String]
      # @param values [Hash]
      # @return [String]
      def self.format_command(command, values)
        liquid_template = Liquid::Template.parse(command, error_mode: :strict2)
        found = extract_placeholders(liquid_template)

        validate_allowed(found)
        validate_required(found)
        validate_missing_values(found, values)

        liquid_template.render!(values.transform_keys(&:to_s), strict_variables: true, strict_filters: true)
      end

      def self.extract_placeholders(liquid_template)
        Liquid::ParseTreeVisitor
          .for(liquid_template.root)
          .add_callback_for(Liquid::VariableLookup) { |node| node.name.to_sym }
          .visit
          .flatten
          .compact
          .to_set
      end

      def self.validate_allowed(found)
        found.each do |placeholder|
          next if ALL.include?(placeholder)

          raise ArgumentError, "Unknown placeholder `#{placeholder}` in command"
        end
      end

      def self.validate_missing_values(placeholders, values)
        placeholders.each do |placeholder|
          next if values.key?(placeholder)

          raise ArgumentError, "Missing key in values for placeholder `#{placeholder}`"
        end
      end

      def self.validate_required(found)
        array = found.to_a
        REQUIRED_COMMAND_PLACEHOLDERS.each { |synonyms|
          next if synonyms.intersect?(array)

          options = synonyms.map { |x| "`#{x}`" }.join(' or ')
          raise ArgumentError, "Missing required placeholders in command: #{options}"
        }
      end

      private_class_method :validate_missing_values, :extract_placeholders, :validate_required
    end
  end
end
