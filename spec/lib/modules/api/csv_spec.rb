# frozen_string_literal: true

describe Api::Csv do
  describe '.dump' do
    it 'generates CSV with simple scalar values' do
      data = [
        { id: 1, name: 'foo' },
        { id: 2, name: 'bar' }
      ]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed.headers).to eq ['id', 'name']
      expect(parsed[0]['id']).to eq '1'
      expect(parsed[0]['name']).to eq 'foo'
      expect(parsed[1]['id']).to eq '2'
      expect(parsed[1]['name']).to eq 'bar'
    end

    it 'expands a Range value into two columns with _lower and _upper suffixes' do
      lower = Time.utc(2007, 10, 5)
      upper = Time.utc(2007, 10, 6)
      data = [{ bucket: (lower...upper) }]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed.headers).to eq ['bucket_lower', 'bucket_upper']
      expect(parsed[0]['bucket_lower']).to eq '2007-10-05T00:00:00.000Z'
      expect(parsed[0]['bucket_upper']).to eq '2007-10-06T00:00:00.000Z'
    end

    it 'formats Range bounds as ISO 8601 strings via as_json' do
      lower = Time.utc(2026, 3, 24, 6, 16, 31, 542_000)
      upper = Time.utc(2026, 3, 25, 6, 16, 31, 542_000)
      data = [{ bucket: (lower...upper) }]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed[0]['bucket_lower']).to eq '2026-03-24T06:16:31.542Z'
      expect(parsed[0]['bucket_upper']).to eq '2026-03-25T06:16:31.542Z'
    end

    it 'uses the end boundary (not last element) for exclusive Range columns' do
      # For an exclusive range lower...upper, Range#end returns upper (not upper - 1)
      lower = Time.utc(2007, 10, 5)
      upper = Time.utc(2007, 10, 6)
      data = [{ bucket: (lower...upper) }]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed[0]['bucket_upper']).to eq upper.as_json
    end

    it 'expands Range values in mixed rows alongside scalar values' do
      lower = Time.utc(2007, 10, 5)
      upper = Time.utc(2007, 10, 6)
      data = [
        { bucket: (lower...upper), count: 5 },
        { bucket: (upper...(upper + 1.day)), count: 3 }
      ]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed.headers).to eq ['bucket_lower', 'bucket_upper', 'count']
      expect(parsed[0]['bucket_lower']).to eq '2007-10-05T00:00:00.000Z'
      expect(parsed[0]['bucket_upper']).to eq '2007-10-06T00:00:00.000Z'
      expect(parsed[0]['count']).to eq '5'
      expect(parsed[1]['bucket_lower']).to eq '2007-10-06T00:00:00.000Z'
      expect(parsed[1]['bucket_upper']).to eq '2007-10-07T00:00:00.000Z'
      expect(parsed[1]['count']).to eq '3'
    end

    it 'returns empty string for empty input' do
      expect(Api::Csv.dump([])).to eq ''
    end

    it 'handles nil values in rows' do
      data = [
        { id: 1, name: nil },
        { id: nil, name: 'bar' }
      ]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true, empty_value: nil)

      expect(parsed[0]['name']).to be_nil
      expect(parsed[1]['id']).to be_nil
    end

    it 'uses the original key name (not expanded) as the base when no Range is present' do
      data = [{ bucket: 'not_a_range', count: 1 }]

      result = Api::Csv.dump(data)
      parsed = CSV.parse(result, headers: true)

      expect(parsed.headers).to include('bucket')
      expect(parsed.headers).not_to include('bucket_lower')
      expect(parsed.headers).not_to include('bucket_upper')
    end
  end
end
