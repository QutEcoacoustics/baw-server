# frozen_string_literal: true

module Report
  # Encapsulates a single step in a report section declaratively, where table:
  # represents the CTE table that will be generated, by applying the procedue
  # (the `as` callable) specified. Dependencies (other CTE tables) can be
  # specified and will be passed to the procedure, allowing steps to be
  # chained together.
  #
  # The idea is that the step procedures (which could themselves have in line
  # Arel, or delegate to a dedicated method; I did a mix) are stand alone
  # Arel::SelectManagers. And then then the actual Report::Section processing
  # ties the result of a procedure to the declared `table:` to create an
  # Arel::Nodes::As.
  class Step
    # @return [Arel::Table] The table that represents the CTE for this step.
    attr_reader :table

    # @return [Array<Arel::Table>] Additional tables this step depends on.
    attr_reader :depends_on

    # @return [#call] A callable that implements the step's logic.
    attr_reader :block

    def initialize(table, depends_on, &block)
      @table = table
      @depends_on = depends_on
      @block = block
    end

    # Call the block, with dependencies and options as arguments
    # Options is always passed as the last argument.
    def call(options)
      step = new_self(options)

      args = step.depends_on + [options]

      select = step.block.call(*args)

      Report::CteNode.new(
        table: step.table,
        select: select,
        depends_on: step.depends_on
      )
    end

    def new_self(options)
      return self unless options[SUFFIX_KEY]

      new_table, new_depends_on = disambiguate_names(options)
      self.class.new(new_table, new_depends_on, &block)
    end

    def disambiguate_names(options)
      string = options[SUFFIX_KEY]

      new_table = suffix(table, string)
      new_depends_on = suffix(depends_on, string)

      [new_table, new_depends_on]
    end

    def suffix(table, string)
      return unless table

      return Arel::Table.new("#{table.name}_#{string}") if table.is_a? Arel::Table

      table.map { |t| suffix(t, string) }
    end
    SUFFIX_KEY = :suffix
  end
end
