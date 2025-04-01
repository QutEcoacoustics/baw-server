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

  let(:test_filter) {
    '{"filter":{"regions.id":{"eq":11}},"sorting":{"order_by":"recorded_date","direction":"desc"},"paging":{"items":25},"projection":{"include":["id","recorded_date","sites.name","site_id","canonical_file_name"]}}'
  }

  let(:test_filter_encoded) {
    #  Base64.urlsafe_encode64(test_filter)
    # Note: padding characters were removed as most encoders do not include them for base64url
    'eyJmaWx0ZXIiOnsicmVnaW9ucy5pZCI6eyJlcSI6MTF9fSwic29ydGluZyI6eyJvcmRlcl9ieSI6InJlY29yZGVkX2RhdGUiLCJkaXJlY3Rpb24iOiJkZXNjIn0sInBhZ2luZyI6eyJpdGVtcyI6MjV9LCJwcm9qZWN0aW9uIjp7ImluY2x1ZGUiOlsiaWQiLCJyZWNvcmRlZF9kYXRlIiwic2l0ZXMubmFtZSIsInNpdGVfaWQiLCJjYW5vbmljYWxfZmlsZV9uYW1lIl19fQ'
  }

  context 'filter_encoded query string parameter' do
    context 'errors' do
      it 'rejects invalid base64 strings (an arbitrary string)' do
        expect {
          create_filter({
            filter_encoded: 'banana'
          }).query_full
        }.to raise_error(
          CustomErrors::FilterArgumentError, 'Filter parameters were not valid: filter_encoded was not a valid RFC 4648 base64url string'
        )
      end

      it 'rejects invalid json (an arbitrary string)' do
        expect {
          create_filter({
            filter_encoded: '0o0o0o0o'
          }).query_full
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /filter_encoded was not a valid JSON payload: /
        )
      end

      it 'rejects invalid base64URL encoding' do
        expect {
          create_filter({
            filter_encoded: 'banana!'
          }).query_full
        }.to raise_error(
          CustomErrors::FilterArgumentError, 'Filter parameters were not valid: filter_encoded was not a valid RFC 4648 base64url string'
        )
      end

      it 'rejects truncated values' do
        expect {
          create_filter({
            filter_encoded: test_filter_encoded[0..-3]
          }).query_full
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /filter_encoded was not a valid JSON payload: /
        )
      end
    end

    context 'when decoding' do
      it 'works as intended' do
        params = {
          filter_encoded: test_filter_encoded
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."id", "audio_recordings"."recorded_date", "sites"."name"
          AS "sites.name", "audio_recordings"."site_id", "audio_recordings"."media_type"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."id"
          IN (
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          LEFT
          OUTER
          JOIN "regions"
          ON "sites"."region_id" = "regions"."id"
          WHERE "regions"."id" = 11))
          ORDER
          BY "audio_recordings"."recorded_date"
          DESC
          LIMIT 25
          OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'ignores an empty filter_encoded value' do
        params = {
          projection: { include: ['id'] },
          filter_encoded: ''
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at"
          IS
          NULL)
          AND ("audio_recordings"."status" = 'ready')
          ORDER BY "audio_recordings"."recorded_date"
          DESC
          LIMIT 25
          OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'checks filter_encoded is practically the same as filter' do
        params_normal = JSON.parse(test_filter)
        params_encoded = { filter_encoded: test_filter_encoded }

        comparison_sql(
          create_filter(params_normal).query_full.to_sql,
          create_filter(params_encoded).query_full.to_sql
        )
      end
    end

    context 'when merging' do
      it 'ensures other query string parameters take priority' do
        params = {
          filter_encoded: test_filter_encoded,
          items: 5,
          filter_id: '1'
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."id", "audio_recordings"."recorded_date", "sites"."name"
          AS "sites.name", "audio_recordings"."site_id", "audio_recordings"."media_type"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          WHERE ("audio_recordings"."deleted_at"
          IS
          NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."id"
          IN (
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          LEFT
          OUTER
          JOIN "regions"
          ON "sites"."region_id" = "regions"."id"
          WHERE "regions"."id" = 11))
          AND ("audio_recordings"."id" = 1)
          ORDER
          BY "audio_recordings"."recorded_date"
          DESC
          LIMIT 5
          OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'ensures other body parameters take priority' do
        params = {
          filter_encoded: test_filter_encoded,
          filter: { id: { eq: 1 } }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."id", "audio_recordings"."recorded_date", "sites"."name"
          AS "sites.name", "audio_recordings"."site_id", "audio_recordings"."media_type"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          WHERE ("audio_recordings"."deleted_at"
          IS
          NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ("audio_recordings"."id" = 1)
          AND ("audio_recordings"."id"
          IN (
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          LEFT
          OUTER
          JOIN "sites"
          ON "audio_recordings"."site_id" = "sites"."id"
          LEFT
          OUTER
          JOIN "regions"
          ON "sites"."region_id" = "regions"."id"
          WHERE "regions"."id" = 11))
          ORDER
          BY "audio_recordings"."recorded_date"
          DESC
          LIMIT 25
          OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end
    end
  end
end
