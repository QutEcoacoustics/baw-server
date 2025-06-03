# frozen_string_literal: true

describe 'Report::Section::Accumulation' do
  let(:params) do
    { options: { start_time: '2000-02-01T00:00:00Z',
                 end_time: '2000-07-02T00:00:00Z',
                 interval: '1 day' } }
  end
  let(:time_series_options) { Report::TimeSeries::Options.call(params) }

  it 'generates the correct SQL for time_range_and_interval' do
    expected_sql = <<~SQL.squish
      SELECT
        tsrange(CAST('2000-02-01 00:00:00' AS timestamp without time zone),
                CAST('2000-07-02 00:00:00' AS timestamp without time zone), '[)') AS "time_range",
        INTERVAL '1 day' AS "bucket_interval"
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:time_range_and_interval][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for number_of_buckets' do
    expected_sql = <<~SQL.squish
      SELECT
        "time_range_and_interval"."time_range",
        "time_range_and_interval"."bucket_interval",
        (SELECT (EXTRACT(EPOCH FROM upper("time_range_and_interval"."time_range")) - EXTRACT(EPOCH FROM LOWER("time_range_and_interval"."time_range"))) / EXTRACT(EPOCH FROM "time_range_and_interval"."bucket_interval") FROM "time_range_and_interval") "bucket_count"
      FROM "time_range_and_interval"
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:number_of_buckets][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for bucketed_time_series' do
    expected_sql = <<~SQL.squish
      SELECT
        bucket_number,
        tsrange(lower(time_range) + ((bucket_number - 1) * bucket_interval), lower(time_range) + (bucket_number * bucket_interval)) AS "time_bucket"
      FROM "number_of_buckets"
      CROSS JOIN generate_series(1, CEIL("number_of_buckets"."bucket_count")) AS bucket_number
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:bucketed_time_series][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for data_with_allocated_bucket' do
    expected_sql = <<~SQL.squish
      SELECT
        width_bucket(EXTRACT(EPOCH FROM "base_table"."start_time_absolute"),
          (SELECT EXTRACT(EPOCH FROM LOWER("number_of_buckets"."time_range")) FROM "number_of_buckets"),
          (SELECT EXTRACT(EPOCH FROM upper("number_of_buckets"."time_range")) FROM "number_of_buckets"),
          (SELECT CAST(CEIL("number_of_buckets"."bucket_count") AS int) FROM "number_of_buckets")) AS "bucket",
        "base_table"."tag_id",
        "base_table"."score"
      FROM "base_table"
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:data_with_allocated_bucket][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for tag_first_appearance' do
    expected_sql = <<~SQL.squish
      SELECT
        "data_with_allocated_bucket"."bucket",
        "data_with_allocated_bucket"."tag_id",
        "data_with_allocated_bucket"."score",
        CASE WHEN row_number() OVER (PARTITION BY "data_with_allocated_bucket"."tag_id" ORDER BY "data_with_allocated_bucket"."bucket") = 1 THEN 1 ELSE 0 END AS "is_first_time"
      FROM "data_with_allocated_bucket"
      WHERE "data_with_allocated_bucket"."bucket" IS NOT NULL
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:tag_first_appearance][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for sum_unique_tags_by_bucket' do
    expected_sql = <<~SQL.squish
      SELECT
        SUM("tag_first_appearance"."is_first_time") AS "sum_new_tags",
        "tag_first_appearance"."bucket"
      FROM "tag_first_appearance"
      GROUP BY "tag_first_appearance"."bucket"
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:sum_unique_tags_by_bucket][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for cumulative_unique_tag_series' do
    expected_sql = <<~SQL.squish
      SELECT
        "bucketed_time_series"."bucket_number",
        "bucketed_time_series"."time_bucket" AS "range",
        CAST(COALESCE(SUM("sum_unique_tags_by_bucket"."sum_new_tags") OVER (ORDER BY "bucketed_time_series"."bucket_number"), 0) AS int) AS "count"
      FROM "bucketed_time_series"
      LEFT OUTER JOIN "sum_unique_tags_by_bucket" ON "bucketed_time_series"."bucket_number" = "sum_unique_tags_by_bucket"."bucket"
      ORDER BY "bucketed_time_series"."bucket_number" ASC
    SQL
    accumulation_collection = Report::Section::Accumulation.process(options: time_series_options)
    result = accumulation_collection[:cumulative_unique_tag_series][:select]
    expect(result.to_sql).to eq(expected_sql)
  end
end
