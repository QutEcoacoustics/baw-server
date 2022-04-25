# frozen_string_literal: true

module Baw
  # Provides DSL for defining a series of steps.
  #
  # @example
  #   RSpec.describe 'user registration and sign in' do
  #     stepwise do
  #       step 'register' do
  #         api.register(user)
  #         mailbox.confirm(user)
  #       end
  #
  #       step 'sign in' do
  #         token = api.sign_in(user)
  #         expect(token).not_to be expired
  #       end
  #     end
  #   end
  #
  module Stepwise
    class Pending < StandardError; end

    # Provides DSL for steps definition and builds execution context.
    module ExampleGroup
      attr_accessor :steps, :step_count

      def self.extended(other)
        other.steps = []
        other.step_count = 0
        other.class_eval do
          it('runs the steps', steps:) do |example|
            steps = example.metadata[:steps]
            steps.each do |step|
              result = run_stepwise_step(step, example)
              break unless result
            end
          end
        end
      end

      # add a little bit of safety - while these should work they would be super confusing
      # since they would run all of our hooks in the middle of a series of steps
      # which themselves do not run those hooks (because steps are just one example)!
      [
        :example, :it, :specify, :focus, :fexample, :fit, :fspecify, :xexample,
        :xit, :xspecify, :skip, :pending
      ].each do |name|
        define_method(name) do |desc, meta, &example|
          # allow our one special example though
          return super(desc, meta, &example) if meta.key?(:steps)

          raise "`#{name}` is not allowed to be included in a `stepwise` block. Use only `step`."
        end
      end

      # Defines new step in a series.
      # @param [String] name - the name of the step
      # @param
      def step(name, &)
        location = caller_locations(1, 1).first
        @step_count += 1

        @steps << Step.new(@step_count, name, location, &)

        @steps.each do |step|
          step.total_steps = @steps.size
        end
      end
    end

    module Example
      # Runs each step in the workflow
      # @api private
      def run_stepwise_step(step, current_example)
        reporter = current_example.reporter
        reporter.publish(:step_started, { step: })

        begin
          instance_eval(&step.block)
        rescue ::Baw::Stepwise::Pending
          reporter.publish(:step_pending, { step: })

          # we don't actually want to raise an error, just stop executing steps
          return false
        rescue StandardError, ::RSpec::Expectations::ExpectationNotMetError => e
          @previous_failed = true
          reporter.publish(:step_failed, { step: })

          #e.backtrace.push "#{step.location}:in `#{step.description}'"
          raise e
        end

        reporter.publish(:step_passed, { step: })

        true
      end

      # Mark a step as pending.
      # Similar to RSpec's `pending` method but modified to work with stepwise.
      def pending(message = nil)
        super
        # force our step runner to stop
        raise ::Baw::Stepwise::Pending, message if steps_example?
      end

      private

      def steps_example?
        current_example = RSpec.current_example
        !!current_example.metadata[:steps]
      end
    end

    class Step
      attr_reader :index, :description, :location, :block

      attr_accessor :total_steps

      def initialize(index, description, location, &block)
        @index = index
        @description = description
        @location = location
        @block = block
      end

      def to_s(location: false)
        indent = Math.log10(total_steps || 1).ceil
        location = location ? " (#{@location.path}:#{@location.lineno})" : ''
        number = "#{@index}.".ljust(indent + 1)
        "#{number} #{@description}#{location}"
      end
    end

    module StepDocumentationFormatter
      def initialize(output)
        super
        @steps = nil
        @current_step = nil
      end

      def example_started(notification)
        super if defined?(super)

        @steps = notification.example.metadata[:steps]
        @current_step = nil
      end

      def step_started(notification)
        @current_step = notification.step
      end

      def step_passed(notification)
        output.puts step_passed_output(notification.step)
      end

      def step_failed(_notification)
        # noop
      end

      def example_passed(passed)
        return super unless steps_example?(passed)

        flush_messages if respond_to? :flush_messages
        @example_running = false
      end

      def example_pending(pending)
        return super unless steps_example?(pending)

        pending.example.metadata[:pending_step] = @current_step
        output.puts step_pending_output(
          @current_step,
          pending.example.execution_result.pending_message
        )
        print_remaining_steps(output)

        flush_messages if respond_to? :flush_messages
        @example_running = false
      end

      def example_failed(failure)
        return super unless steps_example?(failure)

        failure.example.metadata[:failed_step] = @current_step
        output.puts step_failed_output(@current_step)
        print_remaining_steps(output)

        flush_messages if respond_to? :flush_messages
        @example_running = false
      end

      private

      def steps_example?(notification)
        notification.example.metadata[:steps]
      end

      def step_passed_output(step)
        ::RSpec::Core::Formatters::ConsoleCodes.wrap(
          "#{current_indentation}#{step}",
          :success
        )
      end

      def step_skip_output(step, message)
        ::RSpec::Core::Formatters::ConsoleCodes.wrap(
          "#{current_indentation}#{step} " + "(SKIPPED: #{message})",
          :pending
        )
      end

      def step_pending_output(step, message)
        ::RSpec::Core::Formatters::ConsoleCodes.wrap(
          "#{current_indentation}#{step} " + "(PENDING: #{message})",
          :pending
        )
      end

      def step_failed_output(step)
        ::RSpec::Core::Formatters::ConsoleCodes.wrap(
          "#{current_indentation}#{step} (FAILED)",
          :failure
        )
      end

      def print_remaining_steps(output)
        @steps.map do |step|
          next unless step.index > (@current_step&.index || 0)

          output.puts step_skip_output(step, 'a previous step failed')
        end
      end
    end
  end
end

if defined?(::RSpec::Core)
  module ::RSpec
    module Core
      module Formatters
        class DocumentationFormatter
          # register for new events
          ::RSpec::Core::Formatters.register self,
            # the standard events
            :example_started, :example_group_started, :example_group_finished,
            :example_passed, :example_pending, :example_failed,
            # out extra events
            :step_started, :step_passed, :step_failed

          # extend the documentation formatter
          prepend Baw::Stepwise::StepDocumentationFormatter
        end
      end

      # Highlight error step in summary description

      module Formatters
        class ExceptionPresenter
          def encoded_description(description)
            return if description.nil?

            if example.metadata[:steps]
              failed_step = example.metadata[:failed_step]
              pending_step = example.metadata[:pending_step]
              if failed_step || pending_step
                if failed_step
                  status = 'Failed'
                  step = failed_step
                  color = :failure
                end

                if pending_step
                  status = 'Pending'
                  step = pending_step
                  color = :pending
                end

                message = "#{status} step #{step.to_s(location: true)}"
                error = ::RSpec::Core::Formatters::ConsoleCodes.wrap(message, color)
                error = (' ' * (@indentation + 3)) + error
                description += "\n#{error}"
              end
            end

            encoded_string(description)
          end
        end
      end
    end
  end

  # Make sure the documentation formatter listens for stepwise events if it's already registered
  RSpec.world.reporter.registered_listeners(:example_started).each do |formatter|
    if formatter.is_a? RSpec::Core::Formatters::DocumentationFormatter
      RSpec.world.reporter.register_listener formatter, :step_started, :step_passed, :step_failed
    end
  end
end

RSpec.configure do |config|
  # Defines new series of steps. Supports the same arguments as `RSpec.describe`.
  # @see RSpec.describe
  config.alias_example_group_to :stepwise, {
    order: :defined,
    stepwise: true
  }
  config.extend Baw::Stepwise::ExampleGroup, stepwise: true
  config.include Baw::Stepwise::Example, stepwise: true
end

# type hints for solargraph - these are never executed
# rubocop:disable RSpec/EmptyExampleGroup, RSpec/FilePath, RSpec/DescribeClass
RSpec.describe '', skip: true do
  # An alias for an example group that allows steps to be defined in side.
  # A stepwise block can contain only `step` definitions - each of which
  # is executed sequentially as one example. Before and after blocks
  # are only executed once and state is not reset between steps.
  # It is like and is in fact implemented as just one example that
  # is split into smaller steps for easier debugging and reporting.
  # Defining any example within a stepwise block is an error.
  def stepwise; end

  extend Baw::Stepwise::ExampleGroup
  include Baw::Stepwise::Example
end
# rubocop:enable RSpec/EmptyExampleGroup, RSpec/FilePath, RSpec/DescribeClass
