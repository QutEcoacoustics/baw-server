# frozen_string_literal: true

# Defines macro for adding metadata to example groups.
# RSpec does some very complex things when creating examples.
# Code runs in the class context, the instance context, and every describe
# creates a new sub-class of every parent describe.
# This makes it nearly impossible to use standard state mechanisms (like class attributes).
# RSpec's solution is metadata... which can also be impossibly hard to use.
# Our solution wraps the metadata with macros that hopefully make it easier to use.
# We also add a metadata trace tool so we can see the value of metadata as it changes
# through the contexts.
module MetadataState
  class Metadatum
    # @return [Object]
    attr_reader :state
    # @return [Symbol]
    attr_reader :name

    # @return [Class<ExampleGroup>]
    attr_reader :definer

    # @return [Thread::Backtrace::Location]
    attr_reader :location

    def initialize(name, state, definer, location = nil)
      @name = name
      @state = state
      @definer = definer
      # Find the first location in the call stack that is not this file
      # Ans optionally skip more steps too
      location =  location&.first || caller_locations
                  .reject { |l| l.path.ends_with?(__FILE__) }
                  .first

      @location = location
    end

    # Display the provenance of this metadata
    def inspect
      "#{name}=#{state.inspect} #{location}"
    end
  end

  module ExampleGroup
    # Add helper methods for a new item of metadata to keep track of
    # Example:
    # describe 'xxx' do
    #   define_metadata_state :my_variable
    #   # get_my_variable and set_my_variable
    # end
    # Metadata should be changeable per RSpec scope. Changes should flow to children
    # but not back up to parents.
    # This function is intended for use when orchestrating test behaviour.
    # Do not use it to modify or manipulate tests.
    # Good:
    #   - disabling or enabling test adapters declaratively for each test
    #   - recording metadata for tests like API docs
    #   - using state in helper modules to support tests
    # Bad:
    #   - Preparing a test fixture
    #   - Preparing test state
    #   - Creating a test mock
    #   - Changing anything that will affect the outcome of the test
    def define_metadata_state(name, default: nil)
      raise 'name is not a symbol' unless name.is_a?(Symbol)

      # example group getter
      # used in a before(:all)
      define_method "get_#{name}".to_sym do
        self.class.get_metadata_state(name).state
      end

      # example group class getter
      # Example:
      # access `my_variable` in a describe block
      self.class.define_method "get_#{name}".to_sym do
        get_metadata_state(name).state
      end

      # example group setter
      # used in a before(:all)
      define_method "set_#{name}".to_sym do |new_value, location = nil|
        raise 'Cannot change metadata state from within an example' if is_a? ::RSpec::Core::ExampleGroup

        self.class.set_metadata_state(name, new_value, location)
      end

      # example group class setter
      # Example:
      # Set `my_variable` in a describe block
      self.class.define_method "set_#{name}".to_sym do |new_value, location = nil|
        set_metadata_state(name, new_value, location)
      end

      # example getter
      module_exec do
        define_method "get_#{name}".to_sym do
          self.class.metadata[name].state
        end
      end

      # assign default and yeet
      set_metadata_state(name, default)
    end

    def set_metadata_state(name, value, location = nil)
      metadata[name] = Metadatum.new(name, value, self, location)
    end

    def get_metadata_state(name)
      metadata[name]
    end

    def trace_metadata(name, other_metadata = nil)
      metadatas = traverse_metadatas(other_metadata || metadata)
      lines = format_lines(metadatas, name)

      widest = ->(items) { items.map(&:length).max }
      widths = lines.transpose.map(&widest)
      result = [
        "\nMetadata #{name} value in each context:",
        *lines.map { |line|
          line.zip(widths).map { |c, w| c.ljust(w) }.join(' ')
        }
      ]
      result.map(&:rstrip).join("\n")
    end

    private

    def traverse_metadatas(target)
      RSpec::Core::Metadata
        .ascend(target)
        .reverse_each
        .with_index
        .to_a
    end

    def format_location(location)
      location.to_s.gsub(%r{^#{BawApp.root}/}, '')
    end

    def format_value(name, state)
      value = state.nil? ? '<not set>' : state.state.inspect
      "#{name}=#{value}"
    end

    def format_lines(metadatas, name)
      last_value = nil

      metadatas
        .map { |m, index|
        indent = index == 0 ? '' : "#{'  ' * (index - 1)}-> "
        group_name = indent + (m[:description] || '<nil>')
        state = m.key?(name) ? m[name] : nil

        value = format_value(name, state)
        location = ''
        changed = '⬆️ '
        if value != last_value
          last_value = value
          changed = '➡️ '
          location = format_location(state&.location)
        end

        [group_name, value, changed, location]
      }
    end
  end

  def trace_metadata(name)
    self.class.send(:trace_metadata, name, @__current_metadata)
  end

  def self.included(base)
    base.extend ExampleGroup

    # HACK: to make example metadata available to example group instance
    base.before do |example|
      @__current_metadata = example.metadata
    end
  end
end
