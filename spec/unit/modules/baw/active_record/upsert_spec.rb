# frozen_string_literal: true

describe Baw::ActiveRecord::Upsert do
  let(:model) { AudioRecordingStatistics }
  let(:foreign_relation) { FactoryBot.create(:audio_recording) }
  let(:foreign_key) { foreign_relation.id }
  let(:attributes) {
    {
      audio_recording_id: foreign_key,
      segment_download_count: 1,
      segment_download_duration: 120.5
    }
  }

  include SqlHelpers::Example

  it 'checks we are testing a model with ActiveRecord::' do
    expect(model.ancestors).to include(Baw::ActiveRecord::Upsert)
  end

  it 'verifies ::Arel::Visitors::ToSql has been patched with our extensions' do
    expect(model.connection.visitor).to respond_to(:visit_Baw_Arel_Nodes_UpsertStatement)
  end

  it 'validates upsert columns exist in table' do
    expect {
      model.upsert_query({ worf_son_of_mogh: 2 }, on_conflict: :update)
    }.to raise_error(ArgumentError, /worf_son_of_mogh because it does not belong to the table/)
  end

  it 'validates conflict_where must be Arel' do
    expect {
      model.upsert_query(attributes, on_conflict: :update, conflict_where: ' 1 <> 2')
    }.to raise_error(ArgumentError, '`conflict_where` must be an arel expression but was  1 <> 2')
  end

  def expect_insert_then_update(insert, update = omitted = true)
    update = insert if omitted
    result = query.execute

    expect(result).to match insert

    result = query.execute
    expect(result).to match update
    expect(model.count).to eq 1
  end

  context 'with basic upsert' do
    let(:query) {
      model.upsert_query(attributes, on_conflict: :update)
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO UPDATE
        SET "segment_download_count" = EXCLUDED."segment_download_count", "segment_download_duration" = EXCLUDED."segment_download_duration"
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]]
    end
  end

  context 'when returning nothing' do
    let(:query) {
      model.upsert_query(attributes, on_conflict: :update, returning: nil)
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO UPDATE
        SET "segment_download_count" = EXCLUDED."segment_download_count", "segment_download_duration" = EXCLUDED."segment_download_duration"
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update nil
    end
  end

  context 'when returning custom column' do
    let(:query) {
      model.upsert_query(attributes, on_conflict: :update, returning: [:segment_download_duration])
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO UPDATE
        SET "segment_download_count" = EXCLUDED."segment_download_count", "segment_download_duration" = EXCLUDED."segment_download_duration"
        RETURNING "segment_download_duration"
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [120.5]
    end
  end

  context 'with upsert, that does nothing on conflict' do
    let(:query) {
      model.upsert_query(attributes, on_conflict: :do_nothing)
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO NOTHING
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]], []
    end
  end

  context 'with upsert, with custom SQL action for on_conflict' do
    let(:query) {
      model.upsert_query(attributes, on_conflict: [
        Arel.sql('segment_download_count = audio_recording_statistics.segment_download_count * EXCLUDED.segment_download_count'),
        Arel.sql('segment_download_duration = audio_recording_statistics.segment_download_duration * EXCLUDED.segment_download_duration')
      ])
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO UPDATE
        SET segment_download_count = audio_recording_statistics.segment_download_count * EXCLUDED.segment_download_count, segment_download_duration = audio_recording_statistics.segment_download_duration * EXCLUDED.segment_download_duration
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]]

      record = model.first
      expect(record.segment_download_count).to eq 1
      expect(record.segment_download_duration).to eq(120.5 * 120.5)
    end
  end

  context 'with upsert, with custom AREL action for on_conflict' do
    let(:query) {
      sum = Baw::Arel::Helpers.upsert_on_conflict_sum(
        model.arel_table,
        :segment_download_count,
        :segment_download_duration
      )
      model.upsert_query(
        attributes,
        on_conflict: sum
      )
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) DO UPDATE
        SET "segment_download_count" = ("audio_recording_statistics"."segment_download_count" + EXCLUDED."segment_download_count"), "segment_download_duration" = ("audio_recording_statistics"."segment_download_duration" + EXCLUDED."segment_download_duration")
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]]

      record = model.first
      expect(record.segment_download_count).to eq 2
      expect(record.segment_download_duration).to eq(120.5 * 2)
    end
  end

  context 'with a custom conflict target' do
    let(:unique_index) {
      model.connection.schema_cache.indexes(model.table_name).select(&:unique).first
    }
    let(:query) {
      model.upsert_query(attributes, on_conflict: :update, conflict_target: "ON CONSTRAINT #{unique_index.name}")
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT ON CONSTRAINT #{unique_index.name} DO UPDATE
        SET "segment_download_count" = EXCLUDED."segment_download_count", "segment_download_duration" = EXCLUDED."segment_download_duration"
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]]
    end
  end

  context 'with a custom conflict condition' do
    let(:query) {
      model.upsert_query(
        attributes,
        on_conflict: :update,
        conflict_where: Baw::Arel::Helpers.make_unqualified_column(model.arel_table, :audio_recording_id).not_eq(0)
      )
    }

    it 'generates the expected sql' do
      expected = <<~SQL
        INSERT INTO "audio_recording_statistics" ("audio_recording_id", "segment_download_count", "segment_download_duration")
        VALUES ($1, $2, $3)
        ON CONFLICT (audio_recording_id, bucket) WHERE "audio_recording_id" != 0 DO UPDATE
        SET "segment_download_count" = EXCLUDED."segment_download_count", "segment_download_duration" = EXCLUDED."segment_download_duration"
        RETURNING audio_recording_id, bucket
      SQL

      comparison_sql(query.to_sql, expected)
    end

    it 'runs the query (insert, then update)' do
      expect_insert_then_update [[foreign_key, an_instance_of(Range)]]
    end
  end

  context 'with convenience methods' do
    it 'has a upsert counter method' do
      results = []
      results << model.upsert_counter(attributes)
      results << model.upsert_counter(attributes)
      results << model.upsert_counter(attributes)
      results << model.upsert_counter(attributes)

      expect(results).to all(be_nil)

      found = model.first
      expect(found.audio_recording_id).to eq(foreign_key)
      expect(found.segment_download_count).to eq(4)
      expect(found.segment_download_duration).to eq(120.5 * 4)
    end
  end
end
