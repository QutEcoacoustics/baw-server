# frozen_string_literal: true

describe Report::Ctes do
  describe 'Accumulation' do
    describe Report::Ctes::TsRangeAndInterval do
      let(:params) do
        { start_time: '2000-02-01T00:00:00Z',
          end_time: '2000-07-02T00:00:00Z',
          interval: '1 day' }
      end

      it 'generates the correct SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            tsrange(CAST('2000-02-01T00:00:00Z' AS timestamp without time zone),
                    CAST('2000-07-02T00:00:00Z' AS timestamp without time zone),
                    '[)') AS "time_range",
            INTERVAL '1 day' AS "bucket_interval"
        SQL
        debugger
        expect(Report::Ctes::TsRangeAndInterval.new(options: params).to_sql).to eq(expected_sql)
      end
    end

    describe Report::Ctes::BucketCount do
      it 'generates the correct SQL' do
        expect(Report::Ctes::BucketCount.new(options: { interval: '1 day' }).to_sql).to eq <<~SQL.squish
          WITH "time_range_and_interval" AS
          (SELECT
          tsrange(CAST('2000-01-01 00:00:00' AS timestamp without time zone),
                  CAST('2000-01-07 00:00:00' AS timestamp without time zone),
                  '[)') AS "time_range",
          INTERVAL '1 day' AS "bucket_interval")
          SELECT "time_range_and_interval"."time_range", "time_range_and_interval"."bucket_interval",
          (SELECT (EXTRACT(EPOCH FROM upper("time_range_and_interval"."time_range")) - EXTRACT(EPOCH FROM LOWER("time_range_and_interval"."time_range"))) / EXTRACT(EPOCH FROM "time_range_and_interval"."bucket_interval") FROM "time_range_and_interval") "bucket_count"
          FROM "time_range_and_interval"
        SQL
      end

      it 'executes' do
        result = Report::Ctes::BucketCount.new(options: { interval: '1 day' }).execute
        expect(result).to be_a(PG::Result)
        expect(result.fields).to include('time_range', 'bucket_interval', 'bucket_count')
      end
    end
  end
end
