# frozen_string_literal: true

module LoggerHelpers
  # use when you need to log outside of an example group and an example
  def self.logger
    SemanticLogger[LoggerHelpers]
  end

  module ExampleGroup
    def logger
      SemanticLogger[RSpec]
    end
  end

  module Example
    attr_accessor :logger_name

    def logger
      return SemanticLogger[RSpec] if @logger_name.nil?

      @logger ||= SemanticLogger[@logger_name]
    end

    def self.included(example_group)
      example_group.prepend_before do
        @logger_name = example_group.name
      end
    end
  end
end
