# frozen_string_literal: true

describe ApplicationRecord do
  describe '::exec_query_casted' do
    def exec(sql)
      manager = Arel::SelectManager.new
      manager.project(Arel.sql(sql))
      ApplicationRecord.exec_query_casted(manager)
    end

    it 'returns a scalar value for a single-column scalar query' do
      result = exec("42 AS value")
      expect(result).to eq([{ value: 42 }])
    end

    it 'returns the full array for a single-column postgres array query' do
      result = exec("ARRAY[10, 20, 30] AS values")
      expect(result).to eq([{ values: [10, 20, 30] }])
    end

    it 'returns a Range for a single-column tsrange query' do
      result = exec("tsrange('2000-01-01', '2000-01-02') AS bucket")
      expect(result.length).to eq(1)
      row = result.first
      expect(row).to have_key(:bucket)
      expect(row[:bucket]).to be_a(Range)
    end

    it 'returns correctly keyed hashes for a multi-column query' do
      result = exec("1 AS id, 'hello' AS name")
      expect(result).to eq([{ id: 1, name: 'hello' }])
    end
  end
end
