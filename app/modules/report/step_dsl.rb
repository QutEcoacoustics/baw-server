# frozen_string_literal: true

module Report
  module StepDsl
    # TODO: change name to table? or alias
    def step(table, depends_on: [], &block)
      table = Arel::Table.new(table.to_s) if table.is_a? Symbol
      raise ArgumentError, 'block must be provided' unless block
      raise ArgumentError, "table must be a symbol or Arel::Table, got #{table.class}" unless table.is_a?(Arel::Table)

      depends_on = Array(depends_on)
      depends_on = depends_on.map { |d| Arel::Table.new(d.to_s) } if depends_on.all? { |d| d.is_a?(Symbol) }

      unless depends_on.all? { |d| d.is_a?(Arel::Table) }
        raise ArgumentError, 'depends_on must be an Arel::Table or an Array of Arel::Tables'
      end

      steps << Step.new(table, depends_on, &block)
    end

    def steps
      @steps ||= []
    end
  end
end
