# frozen_string_literal: true

describe 'Verifications' do
  create_audio_recordings_hierarchy

  let(:tag) {
    create(:tag, creator: writer_user)
  }

  # the six non-requesting users, in order. run_lengths[i] is how many audio
  # events users[i] verifies (events are taken from the front of the list).
  let(:run_lengths) { [1, 2, 4, 6, 8, 10] }
  let(:users) { create_list(:user, 6) }
  let(:audio_events) { create_list(:audio_event_using_tag, 10, tag:, audio_recording:, creator: writer_user) }

  # how many of the audio events the requesting (writer) user verifies. The
  # leaderboard contexts vary this to move the writer in and out of the top 5.
  let(:writer_run) { 3 }

  before do
    users.zip(run_lengths).each do |user, run|
      audio_events.take(run).each do |audio_event|
        create(:verification, creator: user, audio_event:, tag:)
      end
    end

    audio_events.take(writer_run).each do |audio_event|
      create(:verification, creator: writer_user, audio_event:, tag:)
    end

    # So what will the distribution look like?
    # Each user verifies a `run` (from `run_lengths`) of the `audio_events`.
    # So the first user verifies 1 event, the second verifies 2 etc. So the first event
    # will be verified by all 6 users, while the last event will only be verified by the last user.
    # The additional special case (in a later context) is tag 2 on the first
    # event - which means writer_user verifies both tags on the first event.
    # | -------------------------------------------------------------------------|
    # |                  | verified by user               |                      |
    # |                  | 1 | 2 | 3 | 4 | 5 | 6 | writer | total runs for event |
    # |-------|----------|---|---|---|---|---|---|--------|----------------------|
    # | tag 1 |  event 1 | + | + | + | + | + | + | +      |  >5                  |
    # | tag 1 |  event 2 |   | + | + | + | + | + | +      |  >5                  |
    # | tag 1 |  event 3 |   |   | + | + | + | + | +      |   5                  |
    # | tag 1 |  event 4 |   |   | + | + | + | + |        |   4                  |
    # | tag 1 |  event 5 |   |   |   | + | + | + |        |   3                  |
    # | tag 1 |  event 6 |   |   |   | + | + | + |        |   3                  |
    # | tag 1 |  event 7 |   |   |   |   | + | + |        |   2                  |
    # | tag 1 |  event 8 |   |   |   |   | + | + |        |   2                  |
    # | tag 1 |  event 9 |   |   |   |   |   | + |        |   1                  |
    # | tag 1 | event 10 |   |   |   |   |   | + |        |   1                  |
    # | tag 2 |  event 1 |   |   |   |   |   |   | +      |   1                  |
  end

  let(:body) do
    #   filter: {
    #     'audio_recordings.id': { eq: audio_recording.id }
    #   }
    {}
  end

  def post_stats
    post '/verifications/stats', params: body, **api_headers(writer_token)
  end

  # single row of stats
  def stats
    api_data.first
  end

  it 'can return verification statistics' do
    post_stats
    expect(response).to have_http_status(:ok)
    expect(api_data).to have_attributes(size: 1)
  end

  it 'returns the total verification and verified-event counts' do
    post_stats

    # 1 + 2 + 4 + 6 + 8 + 10 = 31 from the six users, plus 3 from the writer = 34
    expect(stats).to include(
      verifications_count: 34,
      verified_events: 10
    )
  end

  it 'counts the requesting user\'s own verifications' do
    post_stats

    # the writer verifies the first three events (writer_run)
    expect(stats).to include(
      user_verified_count: 3,
      user_verified_events_count: 3
    )
  end

  it 'returns the overrun distribution grouped by verification count' do
    post_stats

    # per-tagging verification counts are [7,6,5,4,3,3,2,2,1,1]
    expect(stats[:overrun_distribution]).to eq([
      { run: 1, count: 2 },
      { run: 2, count: 2 },
      { run: 3, count: 2 },
      { run: 4, count: 1 },
      { run: 5, count: 3, overflow: 'true' }
    ])
  end

  describe 'the leaderboard' do
    it 'places the requesting user within the top 5 at their ranked position' do
      post_stats

      expect(stats[:verification_leaderboard]).to eq([
        { user_id: users[5].id, verification_count: 10, rank: 1 },
        { user_id: users[4].id, verification_count: 8, rank: 2 },
        { user_id: users[3].id, verification_count: 6, rank: 3 },
        { user_id: users[2].id, verification_count: 4, rank: 4 },
        { user_id: writer_user.id, verification_count: 3, rank: 5 }
      ])
    end

    context 'when the requesting user has no verifications' do
      let(:writer_run) { 0 }

      it 'appends them with a null rank' do
        post_stats

        # top 5 kept, plus the requesting user appended last because they are not
        # in the ranking at all (null rank).
        expect(stats[:verification_leaderboard]).to eq([
          { user_id: users[5].id, verification_count: 10, rank: 1 },
          { user_id: users[4].id, verification_count: 8, rank: 2 },
          { user_id: users[3].id, verification_count: 6, rank: 3 },
          { user_id: users[2].id, verification_count: 4, rank: 4 },
          { user_id: users[1].id, verification_count: 2, rank: 5 },
          { user_id: writer_user.id, verification_count: 0, rank: nil }
        ])
      end

      it 'reports zero for the requesting user\'s own counts' do
        post_stats

        expect(stats).to include(
          user_verified_count: 0,
          user_verified_events_count: 0
        )
      end
    end

    context 'when the requesting user ranks outside the top 5' do
      let(:writer_run) { 1 }

      it 'appends them at their rank' do
        # the writer verifies 1 event, tying users[0] at 1 verification. Both are
        # ranked 6th, so the top 5 excludes the writer, but they are still appended.
        post_stats

        expect(stats[:verification_leaderboard]).to eq([
          { user_id: users[5].id, verification_count: 10, rank: 1 },
          { user_id: users[4].id, verification_count: 8, rank: 2 },
          { user_id: users[3].id, verification_count: 6, rank: 3 },
          { user_id: users[2].id, verification_count: 4, rank: 4 },
          { user_id: users[1].id, verification_count: 2, rank: 5 },
          { user_id: writer_user.id, verification_count: 1, rank: 6 }
        ])
      end
    end
  end

  context 'when an audio event has more than one tag verified' do
    let!(:additional_tag) { create(:tag, creator: writer_user) }

    before do
      # a second tag on the first event, verified by the writer, so the first
      # event now has two taggings with verifications.
      create(:verification, creator: writer_user, audio_event: audio_events.first, tag: additional_tag)
    end

    it 'counts each verified tagging for the requesting user but not double-counts events' do
      post_stats

      # the writer now has 4 verifications (events 1,2,3 on tag + event 1 on the
      # additional tag) across only 3 distinct events.
      expect(stats).to include(
        user_verified_count: 4,
        user_verified_events_count: 3
      )
    end

    it 'includes the extra tagging in the totals' do
      post_stats

      # 34 + 1 = 35 verifications; still 10 distinct verified events
      expect(stats).to include(
        verifications_count: 35,
        verified_events: 10
      )
    end

    it 'counts the extra tagging in the overrun distribution' do
      post_stats

      # per-tagging counts now include (event 1, additional tag) => 1, so the
      # single-verification run gains one entry, putting count to 3
      expect(stats[:overrun_distribution]).to eq([
        { run: 1, count: 3 },
        { run: 2, count: 2 },
        { run: 3, count: 2 },
        { run: 4, count: 1 },
        { run: 5, count: 3, overflow: 'true' }
      ])
    end
  end

  context 'when the requesting user is anonymous' do
    it 'returns the correct stats' do
      post '/verifications/stats', params: body, **api_headers(anonymous_token)

      expect(api_data).to match(
        [{ verifications_count: 0,
           verified_events: 0,
           user_verified_count: 0,
           user_verified_events_count: 0,
           overrun_distribution: [{ run: 1, count: 0 }, { run: 2, count: 0 }, { run: 3, count: 0 }, { run: 4, count: 0 },
                                  { run: 5, count: 0, overflow: 'true' }],
           verification_leaderboard: [{ rank: nil, user_id: nil, verification_count: 0 }] }]
      )
    end
  end
end
