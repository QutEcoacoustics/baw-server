module LoggerHelpers
  module Example
    def logger
      @logger ||= SemanticLogger[RSpec]
    end

    def logger_example
      @logger ||= SemanticLogger[logger_name]
    end

    def self.included(example_group)
      logger_name = example_group
      example_group.let(:logger_name) {
        logger_name
      }
    end
  end
end
