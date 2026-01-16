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

    def self.none_value
      @none_value ||= LEVEL_TO_INTEGER_MAP[NONE]
    end

    def self.levels_to_values(levels)
      return [NONE] if levels.blank?

      levels.map { |level| LEVEL_TO_INTEGER_MAP[level] }
    end

    def self.level_to_value(level)
      return LEVEL_TO_INTEGER_MAP[NONE] if level.blank?

      LEVEL_TO_INTEGER_MAP[level]
    end
  end
end
