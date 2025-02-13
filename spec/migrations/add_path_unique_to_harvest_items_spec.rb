# frozen_string_literal: true

require_migration!
describe AddPathUniqueToHarvestItems, :migration do
  let(:longer_blob) do
    { error: 'null', fixes: [{ version: 1, problems: { FL001: { status: 'NoOperation' } } }] }
  end

  before do
    HARVEST_ITEMS = create_harvest_items

    # forat the harvest items into a string of values for insertion
    harvest_values = ''
    HARVEST_ITEMS.each.with_index(1) do |example, index|
      delimit = index == HARVEST_ITEMS.length ? '' : ",\n"
      harvest_values += "(#{example})#{delimit}"
    end
    harvest_values.freeze

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(
        <<~SQL.squish
          DELETE FROM harvest_items;
          INSERT INTO users (user_name, email, encrypted_password)
          VALUES ( 'user1', 'user1@example.com', 'drowssap');

          INSERT INTO projects (name, creator_id)
          VALUES ('project1', (SELECT id FROM users LIMIT 1));

          INSERT INTO sites (name, creator_id)
          VALUES ( 'site1', (SELECT id FROM users LIMIT 1));

          INSERT INTO audio_recordings (data_length_bytes, duration_seconds,
          file_hash, media_type, recorded_date, uuid, creator_id, site_id, uploader_id)
          VALUES ( 1234, 100.0, 'hash1', 'flac', '2025-02-12 12:21:10+1000', 'uuid1',
            (SELECT id FROM users LIMIT 1),
            (SELECT id FROM sites LIMIT 1),
            (SELECT id FROM users LIMIT 1));

          INSERT INTO harvests (project_id, created_at, updated_at)
          VALUES ((SELECT id FROM projects LIMIT 1), '2025-02-12 12:21:10+1000', '2025-02-12 12:21:10+1000');
        SQL
      )
      ActiveRecord::Base.connection.execute(
        <<~SQL.squish
          INSERT INTO harvest_items (path, status, info, audio_recording_id,
          uploader_id, harvest_id, deleted, created_at, updated_at)
          VALUES #{harvest_values};
        SQL
      )
    end

    # check that the data was inserted correctly
    expect(select_count_from('harvest_items')).to eq HARVEST_ITEMS.length
  end

  it 'removes duplicates correctly' do
    migrate!
    results = ActiveRecord::Base.connection.execute(
      <<~SQL.squish
        SELECT path, audio_recording_id, info FROM harvest_items ORDER BY id ASC;
      SQL
    )
    expect(results.ntuples).to eq(3)
    expect(results.values).to eq(
      [
        ['harvest_1/path/one', nil,
         '{"error": "null", "fixes": [{"version": 1, "problems": {"FL001": {"status": "NoOperation"}}}]}'],
        ['harvest_1/path/two', nil,
         '{"error": "null", "fixes": [{"version": 1, "problems": {"FL001": {"status": "NoOperation"}}}]}'],
        ['harvest_1/path/three', 1, '{"error": "null"}']
      ]
    )
    # select from harvest_items and expect that the harvest values match the
    # expected values
    # compare info to longer blob
  end

  # Create harvest items for combinations of status and path
  # @return [Array<String>] values for each harvest item
  def create_harvest_items
    json_blob = ActiveRecord::Base.connection.quote({ error: 'null' }.to_json)
    longer_json_blob = ActiveRecord::Base.connection.quote(
      longer_blob.to_json
    )
    datetime = ActiveRecord::Base.sanitize_sql_array(["'#{Time.zone.now}'"])

    samples = [
      ["'metadata_gathered'", "'harvest_1/path/one'", json_blob],
      ["'metadata_gathered'", "'harvest_1/path/one'", json_blob],
      ["'metadata_gathered'", "'harvest_1/path/one'", longer_json_blob], # keep
      ["'failed'", "'harvest_1/path/two'", json_blob],
      ["'failed'", "'harvest_1/path/two'", json_blob],
      ["'failed'", "'harvest_1/path/two'", longer_json_blob], # keep
      ["'failed'", "'harvest_1/path/three'", json_blob],
      ["'failed'", "'harvest_1/path/three'", longer_json_blob]
    ]

    # keep
    sample_completed = [
      "'harvest_1/path/three'", "'completed'", json_blob, '(SELECT id FROM audio_recordings LIMIT 1)',
      '(SELECT id FROM users LIMIT 1)', '(SELECT id FROM harvests LIMIT 1)', true, datetime, datetime
    ]

    cases = samples.map { |sample|
      sample => [status, path, blob]
      [path, status, blob, 'NULL', '(SELECT id FROM users LIMIT 1)',
       '(SELECT id FROM harvests LIMIT 1)', false, datetime, datetime]
    }

    cases << sample_completed
    cases.map! { _1.join(', ') }
  end

  # Count the number of rows in a table
  # @param table [String]
  # @return [Integer] the number of rows in the table
  def select_count_from(table)
    ActiveRecord::Base.connection.exec_query("select count(*) from #{table}")[0]['count']
  end
end
