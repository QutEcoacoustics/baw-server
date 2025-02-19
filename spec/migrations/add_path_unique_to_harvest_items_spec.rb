# frozen_string_literal: true

require_migration!

describe AddPathUniqueToHarvestItems, :migration do
  let(:longer_blob) do
    { error: 'null', fixes: [{ version: 1, problems: { FL001: { status: 'NoOperation' } } }] }
  end
  let(:datetime) { "'#{Time.zone.now}'" }
  let(:harvest_items) { create_harvest_items }

  before do
    # format the harvest items into a string of values for insertion
    harvest_values = harvest_items.map { |x| "(#{x})" }.join(",\n")

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(
        <<~SQL.squish
          INSERT INTO projects (name, creator_id)
          VALUES ('project1', #{pick_first_id_sql('users')});

          INSERT INTO regions (project_id)
          VALUES (#{pick_first_id_sql('projects')});

          INSERT INTO sites (name, region_id, creator_id)
          VALUES ( 'site1', #{pick_first_id_sql('regions')}, #{pick_first_id_sql('users')});

          INSERT INTO audio_recordings (data_length_bytes, duration_seconds,
          file_hash, media_type, recorded_date, uuid, creator_id, site_id, uploader_id)
          VALUES ( 1234, 100.0, 'hash1', 'flac', #{datetime}, 'uuid1',
            #{pick_first_id_sql('users')},
            #{pick_first_id_sql('sites')},
            #{pick_first_id_sql('users')});

          INSERT INTO harvests (project_id, created_at, updated_at)
          VALUES (#{pick_first_id_sql('projects')}, #{datetime}, #{datetime});

          INSERT INTO harvest_items (path, status, info, audio_recording_id,
          uploader_id, harvest_id, deleted, created_at, updated_at)
          VALUES #{harvest_values};
        SQL
      )
    end

    expect(select_count_from('harvest_items')).to eq harvest_items.length
  end

  it 'removes duplicates correctly' do
    migrate!

    results = ActiveRecord::Base.connection.execute(
      <<~SQL.squish
        SELECT path, audio_recording_id, info FROM harvest_items ORDER BY id ASC;
      SQL
    )
    audio_id = ActiveRecord::Base.connection.select_value(
      <<~SQL.squish
        SELECT id FROM audio_recordings ORDER BY id DESC LIMIT 1;
      SQL
    )

    expect(results.ntuples).to eq(3)
    expect(results.values).to eq(
      [
        # wins because has the largest info
        ['harvest_1/path/one', nil,
         '{"error": "null", "fixes": [{"version": 1, "problems": {"FL001": {"status": "NoOperation"}}}]}'],
        # wins because has the largest info
        ['harvest_1/path/two', nil,
         '{"error": "null", "fixes": [{"version": 1, "problems": {"FL001": {"status": "NoOperation"}}}]}'],
        # wins because it was completed and has a reference to an audio recording
        ['harvest_1/path/three', audio_id, '{"error": "null"}']
      ]
    )
  end

  # Create a series of harvest item value tuples for combinations of status and path
  # @return [Array<String>] values for each harvest item
  def create_harvest_items
    json_blob = ActiveRecord::Base.connection.quote({ error: 'null' }.to_json)
    longer_json_blob = ActiveRecord::Base.connection.quote(longer_blob.to_json)

    samples = [
      ["'metadata_gathered'", "'harvest_1/path/one'"],
      ["'failed'", "'harvest_1/path/two'"],
      ["'failed'", "'harvest_1/path/three'"]
    ]
    sample_completed = [
      "'harvest_1/path/three'", "'completed'", json_blob, pick_first_id_sql('audio_recordings'),
      pick_first_id_sql('users'), pick_first_id_sql('harvests'), true, datetime, datetime
    ]
    common_values = ['NULL', pick_first_id_sql('users'), pick_first_id_sql('harvests'), false, datetime, datetime]

    # For each [status, path] pair in samples, generate three test cases:
    # two with json_blob and one with longer_json_blob (all appended with
    # common_values), and return a flattened array of all test cases.
    cases = samples.flat_map { |status, path|
      [
        [path, status, json_blob, *common_values],
        [path, status, json_blob, *common_values],
        [path, status, longer_json_blob, *common_values]
      ]
    }

    cases << sample_completed
    cases.map! { _1.join(', ') }
  end

  def pick_first_id_sql(table)
    "(SELECT id FROM #{table} LIMIT 1)"
  end

  # Count the number of rows in a table
  # @param table [String]
  # @return [Integer] the number of rows in the table
  def select_count_from(table)
    ActiveRecord::Base.connection.exec_query("select count(*) from #{table}")[0]['count']
  end
end
