# frozen_string_literal: true

module LoggerHelpers
  module ExampleGroup
    def logger
      @logger ||= SemanticLogger[RSpec]
    end
  end

  module Example
    attr_accessor :logger_name

    def logger
      raise 'logger not setup yet' if @logger_name.nil?

      @logger ||= SemanticLogger[@logger_name]
    end

    def self.included(example_group)
      example_group.prepend_before do
        @logger_name = example_group.name
      end
    end
  end
end
