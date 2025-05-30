# frozen_string_literal: true

describe Report do
  describe Report::Expression::Collection do
    let(:collection) { subject }

    it 'initializes with an empty entries hash' do
      expect(collection.entries).to eq({})
    end

    describe '#add' do
      table = Arel::Table.new('test')
      cte = Arel::Nodes::As.new(table, Arel::SelectManager.new)
      report_query = Report::Expression::Cte.new(table, cte)

      it 'adds a report query to the collection' do
        collection.add(:test_query, report_query)
        expect(collection.entries[:test_query]).to eq(report_query)
      end

      it 'raises an error if the object is not a Cte data object' do
        expect { collection.add(:test_query, 'not_valid') }.to raise_error(ArgumentError)
      end
    end

    describe '#gets #tables #ctes' do
      # refactor this - pull out the shared data and add it blocks for each method
      it 'returns an array of CTEs from the entries' do
        table = Arel::Table.new('test')
        cte = Arel::Nodes::As.new(
          table,
          table.project(Arel.star)
        )

        report_query = Report::Expression::Cte.new(table, cte)

        collection.add(:test_query_1, report_query)
        collection.add(:test_query_2, report_query)
        collection.add(:test_query_3, report_query)

        expect(collection.ctes).to include(cte)
        expect(collection.ctes.size).to eq(3)

        actual = table.project(Arel.star).with(collection.ctes).to_sql
        expected = <<~SQL.squish
          WITH "test" AS (SELECT * FROM "test"),
          "test" AS (SELECT * FROM "test"),
          "test" AS (SELECT * FROM "test")
          SELECT * FROM "test"
        SQL

        expect(actual).to eq(expected)

        expect(collection.get(:test_query_1, :test_query_3).ctes).to all(be_a(Arel::Nodes::As))
        expect(collection.get(:test_query_2, :test_query_1).tables).to all(be_a(Arel::Table))
      end
    end

    describe '#select' do
      it 'correctly includes only necessary CTEs with dependencies A <- B, A <- D, (B,D) <- C' do
        # Define tables
        table_a = Arel::Table.new('table_a')
        table_b = Arel::Table.new('table_b')
        table_c = Arel::Table.new('table_c')
        table_d = Arel::Table.new('table_d')

        # Define CTEs with dependencies
        cte_a = Report::Expression::Cte.new(
          table_a,
          Arel::Nodes::As.new(table_a, table_a.project(Arel.star)),
          []
        )

        cte_b = Report::Expression::Cte.new(
          table_b,
          Arel::Nodes::As.new(table_b, table_b.project(Arel.star).where(table_a[:id].eq(table_b[:id]))),
          [:table_a]
        )

        cte_c = Report::Expression::Cte.new(
          table_c,
          Arel::Nodes::As.new(table_c,
            table_c.project(Arel.star).where(table_b[:id].eq(table_c[:id]).and(table_d[:id].eq(table_c[:id])))),
          [:table_b, :table_d]
        )

        cte_d = Report::Expression::Cte.new(
          table_d,
          Arel::Nodes::As.new(table_d, table_d.project(Arel.star).where(table_a[:id].eq(table_d[:id]))),
          [:table_a]
        )

        # create collection and add CTEs
        collection = Report::Expression::Collection.new
        collection.add(:table_a, cte_a)
        collection.add(:table_b, cte_b)
        collection.add(:table_c, cte_c)
        collection.add(:table_d, cte_d)

        # Test selecting from table_c
        select_manager = collection.select(:table_c)
        expected_sql = <<~SQL.squish
          WITH "table_a" AS (SELECT * FROM "table_a"),
               "table_b" AS (SELECT * FROM "table_b" WHERE "table_a"."id" = "table_b"."id"),
               "table_d" AS (SELECT * FROM "table_d" WHERE "table_a"."id" = "table_d"."id"),
               "table_c" AS (SELECT * FROM "table_c" WHERE ("table_b"."id" = "table_c"."id") AND ("table_d"."id" = "table_c"."id"))
          SELECT * FROM "table_c"
        SQL

        expect(select_manager).to be_a(Arel::SelectManager)
        expect(select_manager.froms).to include(table_c)
        expect(select_manager.to_sql).to eq(expected_sql)

        # Test selecting from table_b
        select_manager = collection.select(:table_b)
        expected_sql = <<~SQL.squish
          WITH "table_a" AS (SELECT * FROM "table_a"),
               "table_b" AS (SELECT * FROM "table_b" WHERE "table_a"."id" = "table_b"."id")
          SELECT * FROM "table_b"
        SQL

        expect(select_manager).to be_a(Arel::SelectManager)
        expect(select_manager.froms).to include(table_b)
        expect(select_manager.to_sql).to eq(expected_sql)

        # Test selecting from table_a
        select_manager = collection.select(:table_a)
        expected_sql = <<~SQL.squish
          WITH "table_a" AS (SELECT * FROM "table_a")
          SELECT * FROM "table_a"
        SQL

        expect(select_manager).to be_a(Arel::SelectManager)
        expect(select_manager.froms).to include(table_a)
        expect(select_manager.to_sql).to eq(expected_sql)
      end
    end
  end
end
