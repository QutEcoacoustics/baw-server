# frozen_string_literal: true

module Discardable
  # = Discardable Errors
  #
  # Generic exception class.
  class DiscardableError < StandardError
  end

  # Raised when a model is missing the discard column.
  class MissingDiscardColumn < DiscardableError
    def initialize(model, column)
      super("#{model} is missing the #{column} column and cannot be made discardable")
    end
  end

  # Raised when a discardable method is called on a non-discardable model.
  class NotDiscardableError < DiscardableError
    def initialize
      super('This model is not discardable')
    end
  end

  # Raised by {Discard::Model#discard!}
  class RecordNotDiscarded < DiscardableError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by {Discard::Model#undiscard!}
  class RecordNotUndiscarded < DiscardableError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end
end
