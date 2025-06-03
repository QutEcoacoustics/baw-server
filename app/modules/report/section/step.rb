# frozen_string_literal: true

module Report
  module Section
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

      # @return [#call] A callable that implements the step's logic. Receives
      #   block parameters `(table, *depends_on, options)`.
      attr_reader :as

      def initialize(table, depends_on, as)
        @table = table
        @depends_on = depends_on
        @as = as
      end

      def call(options = {})
        step = new_self(options)
        select = step.as.call(step.table, *step.depends_on, options)

        yield step, select if block_given?
        select
      end

      private

      def new_self(options)
        new_table, new_depends_on = disambiguate_names(options)
        self.class.new(new_table, new_depends_on, as)
      end

      def disambiguate_names(options)
        return [table, depends_on] unless options[SUFFIX_KEY]

        string = options[SUFFIX_KEY]
        new_table = suffix(table, string)
        new_depends_on = suffix(depends_on, string)
        [new_table, new_depends_on]
      end

      SUFFIX_KEY = :suffix

      def suffix(table, string)
        return unless table

        return Arel::Table.new("#{table.name}_#{string}") if table.is_a? Arel::Table

        table.map { |t| suffix(t, string) }
      end
    end
  end
end
