# frozen_string_literal: true

describe Filter::Query do
  create_entire_hierarchy

  include SqlHelpers::Example

  def compare_filter_sql(filter, sql_result)
    filter_query = create_filter(filter)
    comparison_sql(filter_query.query_full.to_sql, sql_result)
    filter_query
  end

  def create_filter(params)
    Filter::Query.new(
      params,
      AudioRecording.all,
      AudioRecording,
      AudioRecording.filter_settings
    )
  end

  context 'when using arrays for combiners' do
    context 'with bad input will error' do
      it 'does not accept an empty array' do
        expect {
          create_filter(
            {
              filter: {
                and: []
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Filter arrays must not be empty')
      end

      it 'does not accept an array with a nil value' do
        expect {
          create_filter(
            {
              filter: [
                nil
              ]
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Filter arrays can only contain other hashes; `` is not valid')
      end

      it 'does not accept an array with a string value' do
        expect {
          create_filter(
            {
              filter: [
                'hello'
              ]
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Filter arrays can only contain other hashes; `hello` is not valid')
      end

      it 'does not accept an array with a numeric value' do
        expect {
          create_filter(
            {
              filter: [
                1
              ]
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Filter arrays can only contain other hashes; `1` is not valid')
      end
    end

    context 'with arrays, combines entries' do
      it 'accepts a root filter array, which is functionally equivalent to an AND operation' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: [
            { recorded_date: { eq: '2022-02-02T22:22' } },
            { recorded_date: { eq: '2022-02-03T22:22' } },
            { site_id: { eq: 3 } }
          ]
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ((("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."recorded_date" = '2022-02-02 22:22:00')
          AND ("audio_recordings"."recorded_date" = '2022-02-03 22:22:00')
          AND ("audio_recordings"."site_id" = 3)))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'accepts filter arrays inside an `and` operator' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: '2022-02-02T22:22'
            },
            and: [
              { id: { gt: 0 } },
              { site_id: { eq: 3 } }
            ]
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."recorded_date" = '2022-02-02 22:22:00')
          AND ((("audio_recordings"."id" > 0)
          AND ("audio_recordings"."site_id" = 3)))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'accepts filter arrays inside an `or` operator' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: '2022-02-02T22:22'
            },
            or: [
              { id: { gt: 0 } },
              { site_id: { eq: 3 } }
            ]
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."recorded_date" = '2022-02-02 22:22:00')
          AND ((("audio_recordings"."id" > 0)
          OR ("audio_recordings"."site_id" = 3)))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'accepts multiple nested operators' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: '2022-02-02T22:22'
            },
            or: [
              {
                and: [
                  { id: { gt: 0 } },
                  { site_id: { eq: 3 } }
                ]
              },
              {
                or: [
                  { id: { gt: 1 } },
                  { site_id: { eq: 4 } }
                ]
              }
            ]
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."recorded_date" = '2022-02-02 22:22:00')
          AND ((((("audio_recordings"."id" > 0) AND ("audio_recordings"."site_id" = 3)))
          OR ((("audio_recordings"."id" > 1) OR ("audio_recordings"."site_id" = 4)))))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end
    end
  end
end
