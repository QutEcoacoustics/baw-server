# frozen_string_literal: true

module Access
  # Permission levels and related constants.
  module Permission
    OWNER = :owner
    WRITER = :writer
    READER = :reader
    NONE = :none

    OWNER_OR_ABOVE = [OWNER].freeze
    WRITER_OR_ABOVE = [OWNER, WRITER].freeze
    READER_OR_ABOVE = [OWNER, WRITER, READER].freeze

    OWNER_OR_BELOW = [OWNER, WRITER, READER].freeze
    WRITER_OR_BELOW = [WRITER, READER].freeze
    READER_OR_BELOW = [READER].freeze

    # Maps permission levels to integers for comparison
    # DO NOT STORE the integer values in the database.
    # The integer values may change if we add new permission levels.
    LEVEL_TO_INTEGER_MAP = {
      OWNER => 3,
      WRITER => 2,
      READER => 1,
      NONE => 0
    }.freeze

    # Returns the integer value for no permission.
    # @return [Integer]
    def self.none_value
      @none_value ||= LEVEL_TO_INTEGER_MAP[NONE]
    end

    # Converts an array of permission levels to their integer values.
    # @param levels [Array<Symbol>] Array of permission levels
    # @return [Array<Integer>]
    def self.levels_to_values(levels)
      # So it would be a valid query to search for an empty set of levels.
      # But we do want to coerce to an array, because that's making an assumption
      # on the intention.
      raise ArgumentError, 'levels cannot be an array' unless levels.is_a?(Array)

      levels.map { |level| level_to_value(level) }
    end

    # Converts a single permission level to its integer value.
    # @param level [Symbol] Permission level to convert. `nil` is treated as `NONE`.
    # @return [Integer]
    def self.level_to_value(level)
      return LEVEL_TO_INTEGER_MAP[NONE] if level.blank?

      LEVEL_TO_INTEGER_MAP[level]
    end
  end
end
