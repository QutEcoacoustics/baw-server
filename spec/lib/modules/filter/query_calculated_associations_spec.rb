describe Filter::Query do
  describe 'calculated custom fields through associations' do
    create_entire_hierarchy

    include SqlHelpers::Example

    def compare_filter_sql(filter_query, sql_result)
      comparison_sql(filter_query.query_full.to_sql, sql_result)
      filter_query
    end

    let(:audio_event_import_file_active_storage_blob_join) do
      <<~SQL
        LEFT
        OUTER
        JOIN "active_storage_attachments"
        ON ("active_storage_attachments"."record_type" = 'AudioEventImportFile')
        AND ("active_storage_attachments"."name" = 'file')
        AND ("active_storage_attachments"."record_id" = "audio_event_import_files"."id")
        LEFT
        OUTER
        JOIN "active_storage_blobs"
        ON "active_storage_blobs"."id" = "active_storage_attachments"."blob_id"
      SQL
    end

    it 'can be filtered' do
      filter_query = Filter::Query.new(
        {
          filter: {
            'audio_events.duration_seconds': { gt: 10 }
          },
          projection: {
            only: ['id', 'created_at']
          }
        },
        Verification.all,
        Verification,
        Verification.filter_settings
      )

      expected = <<~SQL
        SELECT "verifications"."id", "verifications"."created_at"
        FROM "verifications"
        WHERE "verifications"."id"
        IN (
          SELECT "verifications"."id"
          FROM "verifications"
          LEFT OUTER JOIN "audio_events"
          ON "verifications"."audio_event_id" = "audio_events"."id"
          WHERE ("audio_events"."end_time_seconds" - "audio_events"."start_time_seconds") > 10)
        ORDER BY "verifications"."created_at"
        DESC
        LIMIT 25
        OFFSET 0
      SQL

      compare_filter_sql(filter_query, expected)
    end

    it 'can be filtered with a join' do
      filter_query = Filter::Query.new(
        {
          filter: {
            'audio_event_import_files.name': { eq: 'test_import' }
          },
          projection: {
            only: ['id']
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL
        SELECT "audio_events"."id"
        FROM "audio_events"
        WHERE "audio_events"."id"
        IN (
          SELECT "audio_events"."id"
          FROM "audio_events"
          LEFT OUTER JOIN "audio_event_import_files"
          ON "audio_events"."audio_event_import_file_id" = "audio_event_import_files"."id"
          #{audio_event_import_file_active_storage_blob_join}
          WHERE #{AudioEventImportFile.name_arel.to_sql} = 'test_import')
        ORDER BY "audio_events"."created_at"
        DESC
        LIMIT 25
        OFFSET 0
      SQL

      compare_filter_sql(filter_query, expected)
    end

    it 'can be projected' do
      filter_query = Filter::Query.new(
        {
          filter: {},
          projection: {
            only: ['id', 'created_at', 'audio_events.duration_seconds']
          }
        },
        Verification.all,
        Verification,
        Verification.filter_settings
      )

      expected = <<~SQL
        SELECT "verifications"."id", "verifications"."created_at", ("audio_events"."end_time_seconds" - "audio_events"."start_time_seconds") AS "audio_events.duration_seconds"
        FROM "verifications"
        LEFT OUTER JOIN "audio_events"
        ON "verifications"."audio_event_id" = "audio_events"."id"
        ORDER BY "verifications"."created_at"
        DESC
        LIMIT 25
        OFFSET 0
      SQL

      compare_filter_sql(filter_query, expected)
    end

    it 'can be projected with a join' do
      filter_query = Filter::Query.new(
        {
          filter: {
            'audio_event_import_files.name': { eq: 'test_import' }
          },
          projection: {
            only: ['id', 'audio_event_import_files.name']
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL
        SELECT "audio_events"."id", #{AudioEventImportFile.name_arel.to_sql} AS "audio_event_import_files.name"
        FROM "audio_events"
        LEFT
        OUTER
        JOIN "audio_event_import_files"
        ON "audio_events"."audio_event_import_file_id" = "audio_event_import_files"."id"
        #{audio_event_import_file_active_storage_blob_join}
        WHERE "audio_events"."id"
        IN (
          SELECT "audio_events"."id"
          FROM "audio_events"
          LEFT OUTER JOIN "audio_event_import_files"
          ON "audio_events"."audio_event_import_file_id" = "audio_event_import_files"."id"
          #{audio_event_import_file_active_storage_blob_join}
          WHERE #{AudioEventImportFile.name_arel.to_sql} = 'test_import')
        ORDER BY "audio_events"."created_at"
        DESC
        LIMIT 25
        OFFSET 0
      SQL

      compare_filter_sql(filter_query, expected)
    end

    it 'can be sorted' do
      filter_query = Filter::Query.new(
        {
          projection: {
            only: ['id']
          },
          sorting: {
            order_by: 'audio_event_import_files.name',
            direction: 'asc'
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL
        SELECT "audio_events"."id", #{AudioEventImportFile.name_arel.to_sql} AS "audio_event_import_files.name"
        FROM "audio_events"
        LEFT
        OUTER
        JOIN "audio_event_import_files"
        ON "audio_events"."audio_event_import_file_id" = "audio_event_import_files"."id"
        #{audio_event_import_file_active_storage_blob_join}
        ORDER
        BY "audio_event_import_files.name"
        ASC
        LIMIT 25
        OFFSET 0
      SQL

      compare_filter_sql(filter_query, expected)
    end
  end
end
