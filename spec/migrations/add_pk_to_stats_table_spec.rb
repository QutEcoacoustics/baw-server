# frozen_string_literal: true

require_migration!

# So we're testing a data migration.
# A faulty assumption about the equivalence of nulls for a unique constraint has
# lead to hundreds of duplications in the user_statistics table.
# This test creates such duplicates and then asserts that our migration correctly fixes problem
describe AddPkToStatsTable, :migration do
  create_audio_recordings_hierarchy

  def insert_rows(day, bad_behavior: false)
    u = User.new
    u.id = nil

    # insert bucket argument data so we can simulate historical data
    RSpec::Mocks.with_temporary_scope {
      [
        Statistics::AudioRecordingStatistics,
        Statistics::UserStatistics,
        Statistics::AnonymousUserStatistics
      ].each do |klass|
        allow(klass).to(receive(:upsert_counter).and_wrap_original { |m, *args|
          attributes = args[0]
          attributes[:bucket] = ((Date.today.to_datetime + day)...(Date.today.to_datetime + 1.day + day))
          m.call(attributes)
        })
      end

      100.times do
        # a reader user
        Statistics::AudioRecordingStatistics.increment_segment(audio_recording, duration: 1.0)

        Statistics::UserStatistics.increment_segment(reader_user, duration: 1.0)

        # an anonymous user
        Statistics::AudioRecordingStatistics.increment_segment(audio_recording, duration: 1.0)

        if bad_behavior

          Statistics::UserStatistics.increment_segment(u, duration: 1.0)
        else
          Statistics::AnonymousUserStatistics.increment_segment(duration: 1.0)
        end
      end
    }
  end

  before do
    3.times do |day|
      insert_rows(day, bad_behavior: true)
    end

    # these insert operations should have left us with just 3 x 3 rows!
    expect(Statistics::AudioRecordingStatistics.count).to eq(3)
    # unfortunately each anonymous user row was inserted and not deduplicated
    expect(Statistics::UserStatistics.count).to eq(303)
  end

  it 'migrates data correctly' do
    migrate!

    # after migration everything should be nice
    expect(Statistics::AudioRecordingStatistics.count).to eq(3)
    # 1 users * 3 days = 3 rows
    expect(Statistics::UserStatistics.count).to eq(3)
    # no user * 3 days = 3 rows
    expect(Statistics::AnonymousUserStatistics.count).to eq(3)

    # and if we insert more stats
    insert_rows(4, bad_behavior: false)

    # we should only see two new rows for the extra day
    expect(Statistics::AudioRecordingStatistics.count).to eq(4)
    # one user * 4 days = 4 rows
    expect(Statistics::UserStatistics.count).to eq(4)
    # no user * 4 days = 4 rows
    expect(Statistics::AnonymousUserStatistics.count).to eq(4)

    expect(Statistics::AudioRecordingStatistics.totals_for(audio_recording)).to match({
      original_download_count: 0,
      segment_download_count: 800,
      segment_download_duration: 800.0
    })

    expect(Statistics::UserStatistics.totals_for(reader_user)).to match({
      audio_download_duration: 400.0,
      audio_segment_download_count: 400,
      audio_original_download_count: 0
    })

    expect(Statistics::AnonymousUserStatistics.totals).to match({
      audio_download_duration: 400.0,
      audio_segment_download_count: 400,
      audio_original_download_count: 0
    })
  end
end
