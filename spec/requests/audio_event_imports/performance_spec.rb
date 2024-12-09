# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe 'a very large dataset', :slow do
  include_context 'with audio event import context'

  let(:file) { Fixtures.hoot_detective }

  before do
    AudioEvent.delete_all

    contents = file.read
    table = CSV.parse(contents, headers: true)
    ids = table['audio_recording_id'].uniq!.map(&:to_i)
    # SLOW: this creates about 7000 recordings
    duplicate_rows(ids)

    create_import
  end

  def duplicate_rows(ids)
    columns = (AudioRecording.column_names - ['id', 'uuid']).join(', ')
    joined = ids.join(',')

    duplicate_rows_query = <<~SQL.squish
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

      INSERT INTO audio_recordings (id, uuid, #{columns})
      (
        SELECT ids.id, uuid_generate_v4(), #{columns}
        FROM  (
          SELECT #{columns} FROM audio_recordings ORDER BY id DESC LIMIT 1
        ) AS t
        CROSS JOIN unnest(ARRAY[#{joined}]) AS ids(id)
      )
      ON CONFLICT DO NOTHING;
    SQL
    ActiveRecord::Base.connection.execute(duplicate_rows_query)
  end

  def check_event(audio_recording_id, start_time, end_time, *tags)
    events = AudioEvent.includes(:tags).where(
      audio_recording_id:,
      start_time_seconds: start_time,
      end_time_seconds: end_time
    ).to_a

    expect(events.count).to be >= 1
    match = events.any? { |event|
      event.tags.map(&:text).sort == tags.sort
    }

    expect(match).to be true
  end

  it 'performs quickly (commit)' do
    # So before optimization were made to satisfy this test, its took
    # over 3.5 hours to run (importing 22.5k events, across 7 thousands recordings, for 7 tags)
    # and used over 48 GB of memory. The test never finished successfully,
    # and the container was killed by the host for exceeding memory limits.
    expect {
      submit(file)
    }.to perform_under(20).sec.warmup(0)

    expect_success

    expect(AudioEvent.count).to eq 22_539

    # spot check a few events
    check_event(80_896, 4840, 4850, 'Insects')
    check_event(80_781, 2300, 2310, 'wind', 'rain')
    check_event(26_179, 2567, 2577, 'Brush-tailed possum', 'Insects')
    check_event(26_138, 6663, 6673, 'birds', 'Insects', 'frogs')
    check_event(13_517, 130, 140, 'birds', 'Insects', 'wind', 'rain')
    check_event(28, 1368, 1378, 'Southern Boobook', 'birds')
    check_event(1037, 3093, 3103, 'Southern Boobook', 'Eastern Barn Owl', 'birds', 'Insects', 'wind',
      'rain')
  end

  it 'performs quickly (non-commit)' do
    # So before optimization were made to satisfy this test, its took
    # over 3.5 hours to run (importing 22.5k events, across 7 thousands recordings, for 7 tags)
    # and used over 48 GB of memory. The test never finished successfully,
    # and the container was killed by the host for exceeding memory limits.
    expect {
      submit(file, commit: false)
    }.to perform_under(15).sec.warmup(0)

    expect_success

    expect(AudioEvent.count).to eq 0
  end
end
