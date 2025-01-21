# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    # A class that creates a command string from a template and a list of
    # resources.
    # The template is expected  to include placeholders for at least the SOURCE/
    # SOURCE_DIR and OUTPUT tokens.
    #
    # The template uses curly brackets to identify placeholders. e.g.
    # `analysis.exe {source} {output_dir}`.
    #
    # Multiple substitutions can be made for a single placeholder.
    #
    # All substitutions are quoted with double quotes.
    module CommandTemplater
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
      # the basename of the configuration file
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

      module_function

      # Template a command string with the given values.
      # @param command [String]
      # @param values [Hash]
      # @return [String]
      def format_command(command, values)
        found = Set.new

        formatted = command.gsub(/{(.*?)}/) { |_|
          placeholder = ::Regexp.last_match(1).to_sym

          raise ArgumentError, "Invalid placeholder `#{placeholder}` in command" unless ALL.include?(placeholder)

          value = values.fetch(placeholder) { |_|
            raise ArgumentError, "Missing key in values for placeholder `#{placeholder}`"
          }

          found << placeholder

          value = convert(value)

          value.to_s
        }

        validate_required(found.to_a)

        formatted
      end

      def validate_required(found)
        REQUIRED_COMMAND_PLACEHOLDERS.each { |synonyms|
          next if synonyms.intersect?(found)

          options = synonyms.map { |x| "`#{x}`" }.join(' or ')
          raise ArgumentError, "Missing required placeholders in command: #{options}"
        }
      end

      def convert(value)
        case value
        when ::Time
          value.iso8601
        else
          value.to_s
        end
      end
    end
  end
end
