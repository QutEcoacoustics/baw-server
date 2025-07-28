# frozen_string_literal: true

describe Report::Ctes do
  describe 'Accumulation related CTEs' do
    let(:params) do
      { start_time: '2000-02-01T00:00:00Z',
        end_time: '2000-07-02T00:00:00Z',
        interval: '1 day' }
    end

    describe Report::Ctes::TsRangeAndInterval do
      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            tsrange(CAST('2000-02-01T00:00:00Z' AS timestamp without time zone),
                    CAST('2000-07-02T00:00:00Z' AS timestamp without time zone),
                    '[)') AS "time_range",
            INTERVAL '1 day' AS "bucket_interval"
        SQL

        expect(Report::Ctes::TsRangeAndInterval.new(options: params).select_manager.to_sql).to eq(expected_sql)
      end
    end

    describe Report::Ctes::BucketCount do
      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            "time_range_and_interval"."time_range", "time_range_and_interval"."bucket_interval",
            (SELECT
              (EXTRACT(EPOCH FROM upper("time_range_and_interval"."time_range")) - EXTRACT(EPOCH FROM LOWER("time_range_and_interval"."time_range"))) /
               EXTRACT(EPOCH FROM "time_range_and_interval"."bucket_interval")
             FROM "time_range_and_interval") "bucket_count"
          FROM "time_range_and_interval"
        SQL

        expect(Report::Ctes::BucketCount.new(options: params).select_manager.to_sql).to eq(expected_sql)
      end

      context 'when interval is 1 day' do
        it 'correcctly counts buckets' do
          result = Report::Ctes::BucketCount.new(options: params).execute

          bucket_count = result[0]['bucket_count'].to_i

          expected_days =
            ((Time.zone.parse(params[:end_time]) - Time.zone.parse(params[:start_time])).abs / 1.day).to_i

          expect(result.fields).to include('time_range', 'bucket_interval', 'bucket_count')
          expect(bucket_count).to eq(expected_days)
        end
      end
    end

    describe Report::Ctes::BucketTsRange do
      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            bucket_number,
            tsrange(lower(time_range) + ((bucket_number - 1) * bucket_interval),
                    lower(time_range) + (bucket_number * bucket_interval)) AS "time_bucket"
          FROM "bucket_count"
          CROSS JOIN generate_series(1, CEIL("bucket_count"."bucket_count")) AS bucket_number
        SQL
        expect(Report::Ctes::BucketTsRange.new.select_manager.to_sql).to eq(expected_sql)
      end
    end

    describe Report::Ctes::BucketAllocate do
      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            width_bucket(EXTRACT(EPOCH FROM "base_table"."start_time_absolute"),
              (SELECT EXTRACT(EPOCH FROM LOWER("bucket_count"."time_range")) FROM "bucket_count"),
              (SELECT EXTRACT(EPOCH FROM upper("bucket_count"."time_range")) FROM "bucket_count"),
              (SELECT CAST(CEIL("bucket_count"."bucket_count") AS int) FROM "bucket_count")) AS "bucket",
            "base_table"."tag_id",
            "base_table"."score"
          FROM "base_table"
        SQL
        expect(Report::Ctes::BucketAllocate.new.select_manager.to_sql).to eq(expected_sql)
      end
    end

    describe Report::Ctes::BucketFirstTag do
      before { create(:tagging) }

      let(:params) do
        { start_time: '2000-03-26 07:06:59',
          end_time: '2000-04-26 07:06:59',
          interval: '1 day' }
      end

      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            "bucket_allocate"."bucket", "bucket_allocate"."tag_id", "bucket_allocate"."score",
            CASE WHEN row_number() OVER
              (PARTITION BY "bucket_allocate"."tag_id" ORDER BY "bucket_allocate"."bucket") = 1 THEN 1 ELSE 0 END
            AS "is_first_time"
          FROM "bucket_allocate"
          WHERE "bucket_allocate"."bucket" IS NOT NULL
        SQL
        expect(Report::Ctes::BucketFirstTag.new.select_manager.to_sql).to eq(expected_sql)

      end
    end

    describe Report::Ctes::BucketSumUnique do
      it 'generates the correct select manager SQL' do
        expected_sql = <<~SQL.squish
          SELECT
            SUM("bucket_first_tag"."is_first_time") AS "sum_new_tags",
            "bucket_first_tag"."bucket"
          FROM "bucket_first_tag"
          GROUP BY "bucket_first_tag"."bucket"
        SQL
        expect(Report::Ctes::BucketSumUnique.new.select_manager.to_sql).to eq(expected_sql)
      end
    end
  end
end
