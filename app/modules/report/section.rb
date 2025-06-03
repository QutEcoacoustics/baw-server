# frozen_string_literal: true

module Report
  # The primary purpose of a section is to encapsulate the logic for generating
  # a particular result or set of results, allowing for modular and reusable
  # report components. By extending this module, each section defines its own
  # steps using the `step` method, which will be executed when calling
  # `#process` on the section, returning a hash of the results. (see
  # Report::Section::Step)
  #
  # Dependecies are managed through the `depends_on` parameter in the `step`
  # function, and are passed to the step's proc when executed. Dependencies are
  # also stored in the result hash output.
  #
  # I'm using procs for now. All arguments to `step` are yielded to the proc,
  # allowing access to the table and any dependencies from the proc parameters.
  # Any options hash passesd to #process is also yielded at each step, allowing
  # for custom args or behaviour to be injected. This design is also an issue
  # because there is strict arity, and the variable number of arugments yielded
  # can lead to unexpected behaviour unless correctly matching the step's
  # signature.
  #
  # When processed, the result hash structure is analogous to a
  # Report::TableExpression::Collection object. I didn't want to couple these
  # too much which is why process returns a hash. But then wrapping the result
  # hash as a collection gives access to topological sorting and other
  # convenience methods.
  #
  module Section
    # Lazily initialize steps array
    def steps
      @steps ||= []
    end

    # Register a step with validation
    def step(table:, as:, depends_on: nil)
      raise ArgumentError, "table must be Arel::Table, got #{table.class}" unless table.is_a?(Arel::Table)
      raise ArgumentError, "as must respond to :call, got #{as.class}" unless as.respond_to?(:call)

      deps = Array(depends_on)
      unless deps.all? { |d| d.is_a?(Arel::Table) }
        raise ArgumentError, 'depends_on must be an Arel::Table or an Array of Arel::Tables'
      end

      steps << Step.new(table, depends_on, as)
    end

    # Execute all steps and build a results hash
    def process(collection: {}, options: {})
      steps.each_with_object(collection) do |step, result|
        step.call(options) do |step, select|
          key = self::TABLES.key(step.table) || step.table.name.to_sym
          result[key] = {
            table: step.table,
            select: select,
            depends_on: step.depends_on
          }
        end
      end
    end

    module_function

    # Turn a hash of step outputs into a Collection of CTEs
    def transform_to_collection(result_hash = nil, extend_collection = nil)
      result_hash ||= yield
      raise ArgumentError, 'result_hash must be a non-empty Hash' unless result_hash.is_a?(Hash) && result_hash.any?

      extend_collection ||= Report::TableExpression::Collection.new
      result_hash.each do |id, item|
        unless item.is_a?(Hash) && item.key?(:table) && item.key?(:select)
          raise ArgumentError, "item for #{id} must have :table and :select"
        end

        cte = Arel::Nodes::As.new(item[:table], item[:select])
        extend_collection.add(
          id,
          Report::TableExpression::Datum.new(item[:table], cte, item[:depends_on])
        )
      end

      extend_collection
    end
  end
end
