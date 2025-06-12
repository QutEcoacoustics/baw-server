# frozen_string_literal: true

describe 'TableExpression::Collection' do
  # the correct order is A -> B -> C -> E -> D
  test_data = [['table_a'], ['table_b'], ['table_c'], ['table_d'], ['table_e']]
  dependencies = [[], [:table_a], [:table_b], [:table_a, :table_e], [:table_c]]

  tables = test_data.map { |table_name, _| Arel::Table.new(table_name) }
  cte_a, cte_b, cte_c, cte_d, cte_e = tables.map { |table|
    Arel::Nodes::As.new(table, Arel::SelectManager.new)
  }
  ctes_insertion_order = [cte_a, cte_b, cte_c, cte_d, cte_e]
  ctes_topological_order = [cte_a, cte_b, cte_c, cte_e, cte_d]

  collection = Report::TableExpression::Collection.new
  tables.zip(ctes_insertion_order).zip(dependencies).each do |(table, cte), dependencies|
    collection.add(table.name, Report::TableExpression::Datum.new(table, cte, dependencies))
  end

  describe '#get_with_dependencies' do
    it 'returns CTEs in topological order based on dependencies' do
      expect(collection.ctes).to eq(ctes_insertion_order)
      ctes_topological_order = [cte_a, cte_b, cte_c, cte_e, cte_d]
      expect(collection.get_with_dependencies(:table_d).ctes).to eq(ctes_topological_order)
    end
  end

  describe '#select' do
    it 'returns a valid select statement for the specified key, with ordered CTEs' do
      selected = collection.select(:table_c)
      selected.to_sql
      expected_sql = <<~SQL.squish
        WITH "table_a" AS (SELECT), "table_b" AS (SELECT), "table_c" AS (SELECT) SELECT * FROM "table_c"
      SQL
      expect(selected.to_sql).to eq(expected_sql)
    end
  end
end
