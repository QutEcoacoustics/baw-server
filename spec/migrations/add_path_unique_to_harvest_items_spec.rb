# frozen_string_literal: true

# matches against the migration name
# require_migration!

describe 'AddPathUniqueToHarvestItem' do
  let(:user) do
    {
      id: 1,
      user_name: 'user1',
      email: 'user1@example.com',
      encrypted_password: 'drowssap'
    }
  end

  let(:project) do
    {
      id: 1,
      name: 'project1',
      creator_id: 1
    }
  end

  let(:site) do
    {
      id: 1,
      name: 'site1',
      creator_id: 1
    }
  end

  let(:audio_recording) do
    {
      id: 1,
      data_length_bytes: 1000,
      duration_seconds: 100.0,
      file_hash: 'hash1',
      media_type: 'flac',
      recorded_date: '2025-02-11 09:21:10.782309000 +0200',
      uuid: 'uuid1',
      creator_id: 1,
      site_id: 1,
      uploader_id: 1
    }
  end

  let(:harvest) do
    {
      id: 1,
      project_id: 1,
      created_at: '2025-02-12 12:21:10+1000',
      updated_at: '2025-02-12 12:21:10+1000'
    }
  end

  before do
    stub_const('USER', user)
    stub_const('PROJECT', project)
    stub_const('SITE', site)
    stub_const('AUDIO_RECORDING', audio_recording)
    stub_const('HARVEST', harvest)

    ActiveRecord::Base.connection.execute(
      <<~SQL.squish
        BEGIN;

        DELETE FROM users;
        DELETE FROM projects;
        DELETE FROM sites;
        DELETE FROM audio_recordings;
        DELETE FROM harvests;
        DELETE FROM harvest_items;

        INSERT INTO users (id, user_name, email, encrypted_password)
        VALUES (
          #{USER[:id]},
          #{ActiveRecord::Base.connection.quote(USER[:user_name])},
          #{ActiveRecord::Base.connection.quote(USER[:email])},
          #{ActiveRecord::Base.connection.quote(USER[:encrypted_password])});

        INSERT INTO projects (id, name, creator_id)
        VALUES (
          #{PROJECT[:id]},
          #{ActiveRecord::Base.connection.quote(PROJECT[:name])},
          #{PROJECT[:creator_id]});

        INSERT INTO sites (id, name, creator_id)
        VALUES (
          #{SITE[:id]},
          #{ActiveRecord::Base.connection.quote(SITE[:name])},
          #{SITE[:creator_id]});

        INSERT INTO audio_recordings (
          id, data_length_bytes, duration_seconds, file_hash,
          media_type, recorded_date, uuid, creator_id,
          site_id, uploader_id
        )
        VALUES (
          #{AUDIO_RECORDING[:id]},
          #{AUDIO_RECORDING[:data_length_bytes]},
          #{AUDIO_RECORDING[:duration_seconds]},
          #{ActiveRecord::Base.connection.quote(AUDIO_RECORDING[:file_hash])},
          #{ActiveRecord::Base.connection.quote(AUDIO_RECORDING[:media_type])},
          #{ActiveRecord::Base.connection.quote(AUDIO_RECORDING[:recorded_date])},
          #{ActiveRecord::Base.connection.quote(AUDIO_RECORDING[:uuid])},
          #{AUDIO_RECORDING[:creator_id]},
          #{AUDIO_RECORDING[:site_id]},
          #{AUDIO_RECORDING[:uploader_id]}
        );

        INSERT INTO harvests (id, project_id, created_at, updated_at)
        VALUES (
          #{HARVEST[:id]},
          #{HARVEST[:project_id]},
          #{ActiveRecord::Base.connection.quote(HARVEST[:created_at])},
          #{ActiveRecord::Base.connection.quote(HARVEST[:updated_at])});

        COMMIT;
      SQL
    )

    stub_const('HARVEST_ITEMS', create_harvest_items)

    harvest_values = ''
    HARVEST_ITEMS.each.with_index(1) do |example, index|
      delimit = index == HARVEST_ITEMS.length ? '' : ",\n"
      harvest_values += "(#{example})#{delimit}"
    end

    ActiveRecord::Base.connection.execute(
      <<~SQL.squish
        INSERT INTO harvest_items (id, path, status, info, audio_recording_id, uploader_id, harvest_id, deleted, created_at, updated_at)
        VALUES #{harvest_values};
      SQL
    )
  end

  it 'has an irrelevant test' do
    hi = create(:harvest_item)

    expect(hi).to be_valid
  end

  # Create duplicate harvest items for combinations of status and path
  # @param entries_per_combination [Integer]
  # @param blob [Hash] the jsonb data to be stored in the info column
  # @return [Array<String>] values for each harvest item
  def create_harvest_items(entries_per_combination: 3, blob: { error: 'null' })
    statuses = [
      "'metadata_gathered'",
      "'failed'",
      "'failed'"
    ]
    paths = [
      "'harvest_1/path/one'",
      "'harvest_1/path/two'",
      "'harvest_1/path/three'"
    ]

    json_data = ActiveRecord::Base.connection.quote(blob.to_json)
    datetime = ActiveRecord::Base.sanitize_sql_array(["'#{Time.zone.now}'"])

    cases = statuses.zip(paths).flat_map { |status, path|
      Array.new(entries_per_combination) {
        # path, status, info, audio_recording_id, uploader_id, harvest_id, deleted, created_at, updated_at
        [path, status, json_data, 'NULL', 1, 1, false, datetime, datetime]
      }
    }

    # append a status 'completed' harvest as a duplicate
    cases << ["'harvest_1/path/three'", "'completed'", json_data, 1, 1, 1, true, datetime, datetime]

    # prepend a value for 'id' to each sub-array (representing a harvest 'item')
    # collapse each 'item', into a single string
    cases.map!.with_index(1) { |item, index|
      item.unshift(index)
      item.join(', ')
    }.freeze
  end
end
