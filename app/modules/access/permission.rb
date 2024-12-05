# frozen_string_literal: true

module Access
  module Permission
    OWNER = :owner
    WRITER = :writer
    READER = :reader
    NONE = nil

    OWNER_OR_ABOVE = [OWNER].freeze
    WRITER_OR_ABOVE = [OWNER, WRITER].freeze
    READER_OR_ABOVE = [OWNER, WRITER, READER].freeze

    OWNER_OR_BELOW = [OWNER, WRITER, READER].freeze
    WRITER_OR_BELOW = [WRITER, READER].freeze
    READER_OR_BELOW = [READER].freeze
  end
end
