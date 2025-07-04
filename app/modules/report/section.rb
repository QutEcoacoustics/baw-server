# frozen_string_literal: true

module Report
  # A section is the logic that produces a Collection of CTEs. A step is the
  # logic that produces a CTE. A section encapsulates the CTEs required to
  # produce a specific result. Instance options are yielded at each step,
  # allowing for custom args or behaviour to be injected.
  class Section
    extend Report::StepDsl

    def initialize(collection = Report::Collection.new, options: {})
      @collection = collection
      @options = default_options.merge(options)
      validate_options!
    end

    attr_reader :collection, :options, :tables

    def default_options
      {}
    end

    def validate_options!; end

    def prepare
      self.class.steps.each do |current_step|
        result = current_step.call(@options)
        @collection[result.table.name] = result
      rescue StandardError => e
        raise "#{e.class}: #{e.message} (in section: #{self.class.name}, step: #{current_step.table.name})"
      end

      @collection
    end

    def project
      raise NotImplementedError, 'Subclasses must implement the project method'
    end
  end
end
