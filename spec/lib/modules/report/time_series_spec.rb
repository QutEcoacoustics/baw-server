# frozen_string_literal: true

# TODO: update tests - broken post-refactor
RSpec.shared_examples 'a bucket range' do |start_date, end_date, bucket_size, expected_buckets|
  it "returns the expected result for range #{start_date} to #{end_date} with interval #{bucket_size}" do
    postgres_interval = subject.bucket_interval(bucket_size)
    time_series_sql = subject.time_series(start_date, end_date, postgres_interval) # TODO: delete

    result = ActiveRecord::Base.connection.execute(
      <<~SQL.squish
        WITH #{time_series_sql}
        SELECT * FROM all_buckets
    SQL
    ).to_a

    expect(result.size).to eq(expected_buckets)
    expect(result.first['bucket_start_time']).to eq(DateTime.parse(start_date))
    expect(result.last['bucket_end_time']).to eq(DateTime.parse(start_date) + expected_buckets.send(bucket_size))
    expect(result).to eq(result.to_a.sort_by { |bucket| bucket['bucket_start_time'] })
    expect(result).to all(
      satisfy { |bucket| bucket['bucket_start_time'] < bucket['bucket_end_time'] }
    )
    expect(result).to all(
      satisfy { |bucket| bucket['bucket_start_time'] + 1.send(bucket_size) == bucket['bucket_end_time'] }
    )
  end
end

RSpec.shared_examples 'a valid datetime' do |params|
  it 'parses correctly' do
    start_time, end_time = Report::Configuration.parse_report_range(params)
    expect(start_time).to be_a(DateTime)
    expect(end_time).to be_a(DateTime)
  end
end

describe Report::TimeSeries do
  let(:now) { Time.zone.now }

  before do
    # Stub Time.zone.now for consistent testing
    allow(Time.zone).to receive(:now).and_return(now)
  end

  describe '::BUCKET_ENUM' do
    it 'defines the expected bucket sizes' do
      expect(Report::TimeSeries::BUCKET_ENUM).to include(
        'day' => '1 day',
        'week' => '1 week',
        'fortnight' => '2 week',
        'month' => '1 month',
        'year' => '1 year'
      )
    end
  end

  describe '#bucket_interval' do
    it 'returns the correct interval string for valid bucket sizes' do
      values = [['day', '1 day'], ['week', '1 week'], ['fortnight', '2 week'],
                ['month', '1 month'], ['year', '1 year']]
      values.each do |bucket, interval|
        expect(Report::TimeSeries.bucket_interval(bucket)).to eq(interval)
      end
    end

    it 'returns the default interval for invalid bucket sizes' do
      expect(Report::TimeSeries.bucket_interval('invalid')).to eq('1 day')
      expect(Report::TimeSeries.bucket_interval(nil)).to eq('1 day')
    end
  end

  describe '#parse_time_range' do
    it 'returns a lambda that extracts time range from parameters' do
      parser = Report::TimeSeries.parse_time_range
      expect(parser).to be_a(Proc)

      parameters = {
        options: {
          start_time: '2023-01-01T00:00:00Z',
          end_time: '2023-01-31T23:59:59Z'
        }
      }

      result = parser.call(parameters)
      expect(result).to eq(['2023-01-01T00:00:00Z', '2023-01-31T23:59:59Z'])
    end

    it 'handles missing options gracefully' do
      parser = Report::TimeSeries.parse_time_range

      parameters = {}
      result = parser.call(parameters)
      expect(result).to eq([nil, nil])
    end
  end

  describe '#parse_bucket_size' do
    it 'returns a lambda that extracts bucket size from parameters' do
      parser = Report::TimeSeries.parse_bucket_size
      expect(parser).to be_a(Proc)

      parameters = {
        options: {
          bucket_size: 'week'
        }
      }

      result = parser.call(parameters)
      expect(result).to eq('week')
    end

    it 'handles missing options gracefully' do
      parser = Report::TimeSeries.parse_bucket_size

      parameters = {}
      result = parser.call(parameters)
      expect(result).to be_nil
    end
  end

  describe '#string_to_iso8601' do
    it 'converts valid ISO8601 strings to DateTime objects' do
      datetime = Report::TimeSeries.string_to_iso8601('2023-01-01T12:30:45Z')
      expect(datetime).to be_a(DateTime)
    end

    it 'raises ArgumentError for invalid ISO8601 strings' do
      expect {
        Report::TimeSeries.string_to_iso8601('not-a-date')
      }.to raise_error(ArgumentError, 'time string must be valid ISO 8601 dates.')
    end
  end

  describe 'cte tables' do
    it 'expr bucket count default returns the expected SQL for bucket count' do
      expected_sql = <<~SQL.squish
        (SELECT (EXTRACT(EPOCH FROM report_end_time) - EXTRACT(EPOCH FROM report_start_time)) /
          EXTRACT(EPOCH FROM bucket_interval) FROM time_boundaries)
      SQL

      result = subject.expr_bucket_count_default
      expect(result).to match(expected_sql)
    end

    it '#time_boundaries works' do
      # insert start_date and end_date into the table
      # Arel::Nodes::NamedFunction.new('date_trunc', [Arel::Nodes.build_quoted('day'), User.arel_table[:created_at]])
      # date_trunc('day', "users"."created_at")
      # extract = Arel::Nodes::NamedFunction.new('EXTRACT', [expr])
      query = subject.time_boundaries('2025-01-01T00:00:00Z', '2025-01-08T00:00:00Z', '1 day')

      expected_sql = <<~SQL.squish
        "time_boundaries" AS (SELECT
            '2025-01-01T00:00:00Z'::timestamp AS "report_start_time",
            '2025-01-08T00:00:00Z'::timestamp AS "report_end_time",
            INTERVAL '1 day' AS "bucket_interval")
      SQL

      result = execute_query(query)
      result = result[0].to_h

      expect(query.cte.to_sql).to match(expected_sql)
      expect(result['report_start_time']).to eq('2025-01-01T00:00:00Z')
      expect(result['report_end_time']).to eq('2025-01-08T00:00:00Z')
      expect(result['bucket_interval']).to eq('P1D')
    end

    it 'bucket count default works' do
      t = Arel::Table.new(:table)
      start = t[:start_column]
      ends = t[:end_column]
      interval = t[:interval]
      out = subject.bucket_count_default(start, ends, interval)
      expected_sql = <<~SQL.squish
        (EXTRACT(EPOCH FROM "table"."end_column") - EXTRACT(EPOCH FROM "table"."start_column")) /
          EXTRACT(EPOCH FROM "table"."interval")
      SQL
      expect(out.to_sql).to match(expected_sql)
    end
  end

  describe Report::TimeSeries::Options do
    let(:valid_parameters) {
      {
        options: {
          start_time: (now - 10.days).iso8601,
          end_time: (now - 1.day).iso8601,
          bucket_size: 'day'
        }
      }
    }

    let(:mock_time_range_parser) {
      lambda { |_parameters|
        [(now - 10.days).iso8601, (now - 1.day).iso8601]
      }
    }

    let(:mock_bucket_size_parser) {
      lambda { |_parameters|
        'week'
      }
    }

    describe '.call' do
      it 'processes valid parameters correctly' do
        result = Report::TimeSeries::Options.call(valid_parameters)

        expect(result).to include(
          :start_time,
          :end_time,
          :bucket_size,
          :interval
        )

        expect(result[:bucket_size]).to eq('day')
        expect(result[:interval]).to eq('1 day')
      end

      it 'accepts custom parsers' do
        result = Report::TimeSeries::Options.call(
          {},
          time_range_parser: mock_time_range_parser,
          bucket_size_parser: mock_bucket_size_parser
        )

        expect(result[:bucket_size]).to eq('week')
        expect(result[:interval]).to eq('1 week')
      end

      context 'when end time is in the future' do
        it 'sets end_time to current time' do
          parameters = {
            options: {
              start_time: (now - 10.days).iso8601,
              end_time: (now + 5.days).iso8601,
              bucket_size: 'week'
            }
          }

          expect(Rails.logger).to receive(:warn).with('end_time is in the future, defaulting to current time.')

          result = Report::TimeSeries::Options.call(parameters)

          expect(result[:end_time]).to eq(now)
        end
      end

      context 'with invalid bucket size' do
        it 'defaults to day and logs a warning' do
          parameters = {
            options: {
              start_time: (now - 10.days).iso8601,
              end_time: (now - 1.day).iso8601,
              bucket_size: 'invalid_bucket'
            }
          }

          expect(Rails.logger).to receive(:warn).with("Invalid bucket size: invalid_bucket. Defaulting to 'day'.")

          result = Report::TimeSeries::Options.call(parameters)

          expect(result[:bucket_size]).to eq('day')
          expect(result[:interval]).to eq('1 day')
        end
      end

      context 'with nil bucket size' do
        it 'defaults to day and logs a warning' do
          params = valid_parameters
          params[:options][:bucket_size] = nil

          expect(Rails.logger).to receive(:warn).with("No bucket size specified. Defaulting to 'day'.")

          result = Report::TimeSeries::Options.call(params)

          expect(result[:bucket_size]).to eq('day')
          expect(result[:interval]).to eq('1 day')
        end
      end

      context 'with invalid time ranges' do
        it 'raises an error if start_time is after end_time' do
          params = {
            options: {
              start_time: (now - 1.day).iso8601,
              end_time: (now - 10.days).iso8601,
              bucket_size: 'day'
            }
          }

          expect {
            Report::TimeSeries::Options.call(params)
          }.to raise_error(ArgumentError, 'start_time must be before end_time.')
        end

        it 'raises an error if start_time is in the future' do
          params = {
            options: {
              start_time: (now + 1.day).iso8601,
              end_time: (now + 10.days).iso8601,
              bucket_size: 'day'
            }
          }

          expect {
            Report::TimeSeries::Options.call(params)
          }.to raise_error(ArgumentError, 'start_time must be before the current date.')
        end

        it 'raises an error if end_time is in the future and start_time is invalid' do
          params = {
            options: {
              start_time: (now + 5.days).iso8601,
              end_time: (now + 10.days).iso8601,
              bucket_size: 'day'
            }
          }

          expect {
            Report::TimeSeries::Options.call(params)
          }.to raise_error(ArgumentError, 'start_time must be before the current date.')
        end
      end
    end
  end

  describe '#generate_series' do
    it 'returns the expected sql' do
      start_expr = 1
      end_expr = '(SELECT CEILING(bucket_count) FROM calculated_settings)'
      generate_series_sql = subject.generate_series(start_expr, end_expr)
      expected_sql = <<~SQL.squish
        generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer)
      SQL
      expect(generate_series_sql).to match(expected_sql)
    end
  end

  describe '#time_series' do
    it 'returns the expected sql' do
      start_date = '2025-01-01T00:00:00Z'
      end_date = '2025-01-08T00:00:00Z'
      bucket_interval = '1 day'

      time_series_sql = subject.time_series(start_date, end_date, bucket_interval)
      expected_sql = <<~SQL.squish
        time_boundaries AS (
          SELECT
            '2025-01-01T00:00:00Z'::timestamp AS report_start_time,
            '2025-01-08T00:00:00Z'::timestamp AS report_end_time,
            interval '1 day' AS bucket_interval
        ),
        calculated_settings AS (
          SELECT
            (SELECT (EXTRACT(EPOCH FROM report_end_time) - EXTRACT(EPOCH FROM report_start_time)) /
              EXTRACT(EPOCH FROM bucket_interval) FROM time_boundaries) AS bucket_count,
            (SELECT report_start_time FROM time_boundaries) AS min_value,
            (SELECT report_end_time FROM time_boundaries) AS max_value
        ),
        all_buckets AS (
          SELECT
            generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) AS bucket_number,
            (SELECT min_value FROM calculated_settings) +
              ((generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) - 1) *
              (SELECT bucket_interval FROM time_boundaries)) AS bucket_start_time,
            (SELECT min_value FROM calculated_settings) +
              (generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) *
              (SELECT bucket_interval FROM time_boundaries)) AS bucket_end_time
        )
      SQL
      expect(time_series_sql).to match(expected_sql)
    end

    context 'with bucket intervals of day' do
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-08T00:00:00Z', 'day', 7
      it_behaves_like 'a bucket range', '2025-01-01T11:12:00Z', '2025-01-08T00:00:00Z', 'day', 7
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-08T00:00:10Z', 'day', 8
      # non leap year
      it_behaves_like 'a bucket range', '2021-01-01T00:00:00Z', '2022-01-01T00:00:00Z', 'day', 365
      # leap year
      it_behaves_like 'a bucket range', '2000-01-01T00:00:00Z', '2001-01-01T00:00:00Z', 'day', 366
    end

    context 'with bucket intervals of week' do
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-08T00:00:00Z', 'week', 1
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-15T00:00:00Z', 'week', 2
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-16T00:00:00Z', 'week', 3
    end

    context 'with bucket intervals of fortnight' do
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-15T00:00:00Z', 'fortnight', 1
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-29T00:00:00Z', 'fortnight', 2
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-30T00:00:00Z', 'fortnight', 3
    end

    context 'with bucket intervals of year' do
      it_behaves_like 'a bucket range', '2020-01-01T00:00:00Z', '2021-01-01T00:00:00Z', 'year', 1
      it_behaves_like 'a bucket range', '2020-01-01T00:00:00Z', '2021-02-01T00:00:00Z', 'year', 2
      it_behaves_like 'a bucket range', '2020-12-31T23:58:58Z', '2023-01-01T00:00:00Z', 'year', 3
    end

    context 'with bucket intervals of month' do
      it_behaves_like 'a bucket range', '2020-01-01T00:00:00Z', '2020-02-01T00:00:00Z', 'month', 1
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-01-02T00:00:00Z', 'month', 1
      it_behaves_like 'a bucket range', '2025-01-01T00:00:00Z', '2025-02-02T00:00:00Z', 'month', 2
      it_behaves_like 'a bucket range', '2020-01-01T00:00:00Z', '2020-03-01T00:00:00Z', 'month', 2
      it_behaves_like 'a bucket range', '2020-01-01T00:00:00Z', '2021-01-01T00:00:00Z', 'month', 12
      it_behaves_like 'a bucket range', '2020-06-01T00:00:00Z', '2023-04-01T00:00:00Z', 'month', 34
    end
  end
end
