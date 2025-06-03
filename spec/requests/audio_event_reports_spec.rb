# frozen_string_literal: true

describe 'Audio Event Reports' do
  # create some users to verify events
  let(:users) { create_list(:user, 4) }
  let(:creator) { users.first }
  let(:provenance) { create(:provenance, creator: creator, score_minimum: 0, score_maximum: 1) }
  let(:start_date) { DateTime.parse('2025-01-01T00:00:00Z') }
  let(:report_length) { 7.days }
  let(:tags) {
    tag_keys = [:koala, :whip_bird, :riflebird, :magpie]
    tag_keys.index_with { |tag_name| create(:tag, text: tag_name) }
  }

  let(:project) { create(:project, creator: creator) }
  let(:region) { create(:region, project: project, creator: creator) }
  let(:site_one) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }
  let(:site_two) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }

  let(:writer_token) { Creation::Common.create_user_token(creator) }
  let(:default_filter) {
    {
      filter: {},
      options: {
        bucket_size: 'day',
        start_time: start_date,
        end_time: start_date + report_length
      }
    }
  }

  before do
    script = create(:script, creator: creator, provenance: provenance)
    analysis_job = create(:analysis_job, project: project, creator: creator, scripts: [script])
    result = [AnalysisJobsItem::RESULT_SUCCESS, AnalysisJobsItem::RESULT_FAILED,
              AnalysisJobsItem::RESULT_SUCCESS, AnalysisJobsItem::RESULT_CANCELLED].cycle

    # create enough variety to test the basic report features:
    # - for two sites, create recordings with a range of dates and start times
    # - for each recording, create one or more events, with zero or more
    #   verifications
    # - create an analysis job with a result for each recording

    with_recording(site: site_one, creator: creator, date: start_date) do |recording|
      event(creator: creator, provenance:, recording:, start: 5, tag: tags[:koala], score: 0.71)
      event(creator: creator, provenance:, recording:, start: 3600, tag: tags[:koala], score: 0.2)
      event(creator: creator, provenance:, recording:, start: 7600, tag: tags[:whip_bird], score: 0.09,
        confirmations: ['correct', 'correct'], users: users)

      create(:analysis_jobs_item, analysis_job:, script:, result: result.next, audio_recording: recording)
    end

    with_recording(site: site_one, creator: creator, date: start_date + 2.days) do |recording|
      event(creator: creator, provenance:, recording:, start: 18_000, tag: tags[:riflebird], score: 0.86)
      event(creator: creator, provenance:, recording:, start: 20_000, tag: tags[:koala], score: 0.2,
        confirmations: ['correct', 'correct', 'correct', 'incorrect'], users: users)

      create(:analysis_jobs_item, analysis_job:, script: script, result: result.next, audio_recording: recording)
    end

    # same date as above but different site (overlapping recordings)
    with_recording(site: site_two, creator: creator, date: start_date + 2.days) do |recording|
      event(creator: creator, provenance:, recording:, start: 5, tag: tags[:koala], score: 0.12)
      create(:analysis_jobs_item, analysis_job:, script: script, result: result.next, audio_recording: recording)
    end

    with_recording(site: site_one, creator: creator, date: start_date + 5.days) do |recording|
      event(creator: creator, provenance:, recording:, start: 5, tag: tags[:koala], score: 0.84)

      # make one event with two tags; significant edge case most likely to cause issues
      event(creator: creator, provenance:, recording:, start: 3600, tag: tags[:whip_bird], score: 0.26,
        confirmations: ['incorrect', 'incorrect'], users: users) do |event|
          create(:tagging, audio_event: event, tag: tags[:magpie])
        end
      create(:analysis_jobs_item, analysis_job:, script: script, result: result.next, audio_recording: recording)
    end
  end

  it 'returns a report with the correct structure' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    expected_report_structure = {
      site_ids: all(an_instance_of(Integer)),
      region_ids: all(an_instance_of(Integer)),
      tag_ids: all(an_instance_of(Integer)),
      provenance_ids: all(an_instance_of(Integer)),
      generated_date: an_instance_of(String),
      bucket_count: an_instance_of(Integer),
      audio_events_count: an_instance_of(Integer),
      audio_recording_ids: all(an_instance_of(Integer)),
      event_summaries: all(
        match(
          provenance_id: an_instance_of(Integer),
          tag_id: an_instance_of(Integer),
          events: match(
            count: an_instance_of(Integer),
            consensus: be_a(Numeric).or(be_nil),
            verifications: an_instance_of(Integer)
          ),
          score_histogram: all(
            match(
              max: be_a(Numeric),
              min: be_a(Numeric),
              bins: all(be_a(Numeric)),
              mean: be_a(Numeric),
              standard_deviation: be_a(Numeric).or(be_nil)
            )
          )
        )
      ),
      accumulation_series: all(
        match(
          bucket_number: an_instance_of(Integer),
          range: match([an_instance_of(String), an_instance_of(String)]),
          count: an_instance_of(Integer)
        )
      ),
      composition_series: all(
        match(
          range: match([an_instance_of(String), an_instance_of(String)]),
          tag_id: an_instance_of(Integer),
          ratio: be_a(Numeric),
          events: match(
            count: an_instance_of(Integer),
            verifications: an_instance_of(Integer),
            consensus: (be_a(Numeric).or be_nil)
          )
        )
      ),
      coverage_series: match(
        recording: all(
          match(
            range: match([an_instance_of(String), an_instance_of(String)]),
            density: be_a(Numeric)
          )
        ),
        analysis: all(
          match(
            type: an_instance_of(String),
            range: match([an_instance_of(String), an_instance_of(String)]),
            density: be_a(Numeric)
          )
        )
      )
    }

    expect(response).to have_http_status(:ok)
    expect(api_data).to match(expected_report_structure)
  end

  it 'returns a report with the correct top level results' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)
    expected_site_ids = [site_one.id, site_two.id].sort
    expected_region_ids = [region.id].sort
    expected_tag_ids = tags.values.map(&:id).sort
    expected_provenance_ids = [provenance.id].sort
    expected_audio_recording_ids = AudioRecording.last(4).map(&:id).sort

    expect(api_data[:site_ids].sort).to eq(expected_site_ids)
    expect(api_data[:region_ids].sort).to eq(expected_region_ids)
    expect(api_data[:tag_ids].sort).to eq(expected_tag_ids)
    expect(api_data[:provenance_ids].sort).to eq(expected_provenance_ids)

    expect(api_data[:generated_date]).to start_with(Time.zone.now.year.to_s)

    expect(api_data[:bucket_count]).to eq(7)
    expect(api_data[:audio_events_count]).to eq(8)
    expect(api_data[:audio_recording_ids].sort).to eq(expected_audio_recording_ids)
  end

  it 'returns the correct event summary results' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    # check first element's values
    expect(api_data[:event_summaries].first).to match(
      provenance_id: provenance.id,
      tag_id: tags[:koala].id,
      events: {
        count: 5,
        consensus: 0.75,
        verifications: 4
      },
      score_histogram: [
        a_hash_including(
          max: 0.84,
          min: 0.12,
          mean: 0.414,
          standard_deviation: 0.334
        )
      ]
    )
  end

  it 'returns the correct accumulation series results' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    expect(api_data[:accumulation_series].length).to eq(report_length.in_days)

    expected_counts = [2, 2, 3, 3, 3, 4, 4]

    api_data[:accumulation_series].each_with_index do |bucket, index|
      expect(bucket[:count]).to eq(expected_counts[index])

      expect(bucket[:range].first).to start_with('2025-01-')
      expect(bucket[:range].last).to start_with('2025-01-')
    end
  end

  it 'returns the correct composition series' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    # composition should always have one entry per tag, per bucket
    expected_length = Tag.count * report_length.in_days

    expect(api_data[:composition_series].length).to eq(expected_length)
  end

  it 'returns the correct coverage series' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    # these are the coverage results
    expect(api_data[:coverage_series][:recording].length).to eq(3)
    expect(api_data[:coverage_series][:analysis].length).to eq(4)

    # check the first recording entry
    first_recording = api_data[:coverage_series][:recording].first
    expect(first_recording[:range].first).to start_with('2025-01-01')
    expect(first_recording[:range].last).to start_with('2025-01-01')
    expect(first_recording[:density]).to eq(1.0)

    # check the first analysis entry
    first_analysis = api_data[:coverage_series][:analysis].first
    expect(first_analysis[:type]).to eq('success')
    expect(first_analysis[:range].first).to start_with('2025-01-03')
    expect(first_analysis[:range].last).to start_with('2025-01-03')
    expect(first_analysis[:density]).to eq(1.0)
  end

  # temporary catch-all during development
  it 'matches these results' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    # Extract IDs and tag lookups to variables to avoid repeated queries
    all_site_ids = Site.pluck(:id).sort
    all_region_ids = Region.pluck(:id).sort
    all_tag_ids = Tag.pluck(:id).sort
    all_provenance_ids = Provenance.pluck(:id).sort
    last_audio_recording_ids = AudioRecording.last(4).map(&:id).sort
    koala_tag_id = Tag.find_by(text: :koala).id
    whip_bird_tag_id = Tag.find_by(text: :whip_bird).id
    riflebird_tag_id = Tag.find_by(text: :riflebird).id
    magpie_tag_id = Tag.find_by(text: :magpie).id
    first_provenance_id = Provenance.first.id
    expected =
      {
        site_ids: all_site_ids,
        region_ids: all_region_ids,
        tag_ids: all_tag_ids,
        provenance_ids: all_provenance_ids,
        bucket_count: 7,
        audio_events_count: 8,
        audio_recording_ids: last_audio_recording_ids,
        event_summaries: [
          { provenance_id: first_provenance_id, tag_id: koala_tag_id,
            events: { count: 5, consensus: 0.75, verifications: 4 }, score_histogram: [{ max: 0.84, min: 0.12, bins: [0, 0, 0, 0, 0, 0, 0.2, 0, 0, 0, 0.2, 0.2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.2, 0, 0, 0, 0, 0, 0, 0.2, 0, 0, 0, 0, 0, 0, 0], mean: 0.414, standard_deviation: 0.334 }] },
          { provenance_id: first_provenance_id, tag_id: whip_bird_tag_id, events: { count: 2, consensus: 1, verifications: 4 },
            score_histogram: [{ max: 0.26, min: 0.09, bins: [0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], mean: 0.175, standard_deviation: 0.12 }] },
          { provenance_id: first_provenance_id, tag_id: riflebird_tag_id, events: { count: 1, consensus: nil, verifications: 0 },
            score_histogram: [{ max: 0.86, min: 0.86, bins: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0], mean: 0.86, standard_deviation: nil }] },
          { provenance_id: first_provenance_id, tag_id: magpie_tag_id, events: { count: 1, consensus: nil, verifications: 0 },
            score_histogram: [{ max: 0.26, min: 0.26, bins: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], mean: 0.26, standard_deviation: nil }] }
        ],
        accumulation_series: [
          { bucket_number: 1, range: ['2025-01-01T00:00:00.000+00:00', '2025-01-02T00:00:00.000+00:00'], count: 2 },
          { bucket_number: 2, range: ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00'], count: 2 },
          { bucket_number: 3, range: ['2025-01-03T00:00:00.000+00:00', '2025-01-04T00:00:00.000+00:00'], count: 3 },
          { bucket_number: 4, range: ['2025-01-04T00:00:00.000+00:00', '2025-01-05T00:00:00.000+00:00'], count: 3 },
          { bucket_number: 5, range: ['2025-01-05T00:00:00.000+00:00', '2025-01-06T00:00:00.000+00:00'], count: 3 },
          { bucket_number: 6, range: ['2025-01-06T00:00:00.000+00:00', '2025-01-07T00:00:00.000+00:00'], count: 4 },
          { bucket_number: 7, range: ['2025-01-07T00:00:00.000+00:00', '2025-01-08T00:00:00.000+00:00'], count: 4 }
        ],
        composition_series: [
          { range: ['2025-01-01T00:00:00.000+00:00', '2025-01-02T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.67, events: { count: 2, verifications: 0, consensus: nil } },
          { range: ['2025-01-01T00:00:00.000+00:00', '2025-01-02T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.33, events: { count: 1, verifications: 2, consensus: 1 } },
          { range: ['2025-01-01T00:00:00.000+00:00', '2025-01-02T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-01T00:00:00.000+00:00', '2025-01-02T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-03T00:00:00.000+00:00', '2025-01-04T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.67, events: { count: 2, verifications: 4, consensus: 0.75 } },
          { range: ['2025-01-03T00:00:00.000+00:00', '2025-01-04T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-03T00:00:00.000+00:00', '2025-01-04T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.33, events: { count: 1, verifications: 0, consensus: nil } },
          { range: ['2025-01-03T00:00:00.000+00:00', '2025-01-04T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-04T00:00:00.000+00:00', '2025-01-05T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-04T00:00:00.000+00:00', '2025-01-05T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-04T00:00:00.000+00:00', '2025-01-05T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-04T00:00:00.000+00:00', '2025-01-05T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-05T00:00:00.000+00:00', '2025-01-06T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-05T00:00:00.000+00:00', '2025-01-06T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-05T00:00:00.000+00:00', '2025-01-06T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-05T00:00:00.000+00:00', '2025-01-06T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-06T00:00:00.000+00:00', '2025-01-07T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.33, events: { count: 1, verifications: 0, consensus: nil } },
          { range: ['2025-01-06T00:00:00.000+00:00', '2025-01-07T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.33, events: { count: 1, verifications: 2, consensus: 1 } },
          { range: ['2025-01-06T00:00:00.000+00:00', '2025-01-07T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-06T00:00:00.000+00:00', '2025-01-07T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.33, events: { count: 1, verifications: 0, consensus: nil } },
          { range: ['2025-01-07T00:00:00.000+00:00', '2025-01-08T00:00:00.000+00:00'], tag_id: koala_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-07T00:00:00.000+00:00', '2025-01-08T00:00:00.000+00:00'], tag_id: whip_bird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-07T00:00:00.000+00:00', '2025-01-08T00:00:00.000+00:00'], tag_id: riflebird_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } },
          { range: ['2025-01-07T00:00:00.000+00:00', '2025-01-08T00:00:00.000+00:00'], tag_id: magpie_tag_id,
            ratio: 0.0, events: { count: 0, verifications: 0, consensus: nil } }
        ],
        coverage_series: { recording: [{ range: ['2025-01-01T00:00:00.000+00:00', '2025-01-01T16:40:00.000+00:00'], density: 1.0 }, { range: ['2025-01-03T00:00:00.000+00:00', '2025-01-03T16:40:00.000+00:00'], density: 1.0 }, { range: ['2025-01-06T00:00:00.000+00:00', '2025-01-06T16:40:00.000+00:00'], density: 1.0 }],
                           analysis: [{ type: 'success', range: ['2025-01-03T00:00:00.000+00:00', '2025-01-03T16:40:00.000+00:00'], density: 1.0 },
                                      { type: 'cancelled',
                                        range: ['2025-01-06T00:00:00.000+00:00', '2025-01-06T16:40:00.000+00:00'], density: 1.0 },
                                      { type: 'failed',
                                        range: ['2025-01-03T00:00:00.000+00:00', '2025-01-03T16:40:00.000+00:00'], density: 1.0 },
                                      { type: 'success',
                                        range: ['2025-01-01T00:00:00.000+00:00', '2025-01-01T16:40:00.000+00:00'], density: 1.0 }] }
      }
    actual_without_date = api_data.except(:generated_date)
    expect(actual_without_date).to eq(expected)
  end
end

# Create a recording with default values from current scope
# @yield [AudioRecording] optional block to yield the created recording
def with_recording(site:, creator:, date:)
  recording = create(:audio_recording, site: site, creator: creator, recorded_date: date)
  block_given? ? yield(recording) : recording
end

# Create event with default values from current scope.
# Pass optional arguments for creating verifications:
# @param [Array<String>] confirmations optional array of verification
#   confirmation values
# @param [Array<User>] users optional array of users for creating verifications
#   User.length must be >= confirmations.length
# @yield [event] optional block to yield the created event
def event(recording:, creator:, start:, provenance:, tag:, score:, **args)
  event = create(:audio_event_tagging, audio_recording: recording, creator: creator,
    start_time_seconds: start, provenance: provenance, tag: tag, score: score, **args)
  yield(event) if block_given?
end
