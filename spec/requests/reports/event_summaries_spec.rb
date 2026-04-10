# frozen_string_literal: true

describe 'reports/event_summaries' do
  create_audio_recordings_hierarchy

  let(:tags) { create_list(:tag, 4, creator: writer_user) }
  let(:provenances) {
    [create(:provenance, creator: writer_user, score_minimum: 0, score_maximum: 1),
     create(:provenance, creator: writer_user, score_minimum: nil, score_maximum: nil)]
  }

  # Each object in represents a set of events for a specific tag/provenance group
  let!(:records) {
    [
      # expect 1 count in underflow and overflow; expect inclusive upper final bin works
      { tag_ids: [0, 0, 0, 0, 0, 0],
        scores: [-1, 0, 0.5, 0.51, 1, 2],
        provenances: [0, 0, 0, 0, 0, 0] },

      # when all scores are nil for a group (t, p): scores_binned: [], summary statistics: nil
      { tag_ids: [1, 1],
        scores: [nil, nil],
        provenances: [0, 0] },

      # when provenance has no min/max, a min/max is calculated from the scores in the group (t, p)
      { tag_ids: [2, 2, 2, 2, 2],
        scores: [-0.4, -0.1, 0, 0.2, 0.3],
        provenances: [1, 1, 1, 1, 1] },

      # when all scores in group are equal and provenance has no min/max set, expect all scores in last bin
      { tag_ids: [3, 3, 3],
        scores: [0.5, 0.5, 0.5],
        provenances: [1, 1, 1] },

      # when provenance is nil, (t, p): scores_binned: [], summary statistics: nil
      { tag_ids: [0, 0],
        scores: [0.1, 0.2],
        provenances: [nil, nil] }
    ]
  }

  let(:nil_result) do
    {
      score_mean: nil,
      score_stddev: nil,
      score_minimum: nil,
      score_maximum: nil,
      score_histogram: nil
    }
  end

  let(:expected_data) do
    [
      {
        tag_id: tags[0].id,
        provenance_id: provenances[0].id,
        events: 6,
        score_mean: 0.5016666666666667,
        score_stddev: 1.0000083332986114,
        score_minimum: -1.0,
        score_maximum: 2.0,
        score_histogram:
       {
         bins: sparse_bins(0 => 1, 25 => 2, 49 => 1),
         maximum: 1.0,
         minimum: 0.0,
         underflow: 1,
         overflow: 1
       }
      },
      { tag_id: tags[0].id, provenance_id: nil, events: 2, **nil_result },
      { tag_id: tags[1].id, provenance_id: provenances[0].id, events: 2, **nil_result },
      {
        tag_id: tags[2].id,
        provenance_id: provenances[1].id,
        events: 5,
        score_mean: 0.0,
        score_stddev: 0.27386127875258304,
        score_minimum: -0.4,
        score_maximum: 0.3,
        score_histogram:
        {
          bins: sparse_bins(0 => 1, 21 => 1, 28 => 1, 42 => 1, 49 => 1),
          maximum: 0.3,
          minimum: -0.4,
          underflow: 0,
          overflow: 0
        }
      },
      {
        tag_id: tags[3].id,
        provenance_id: provenances[1].id,
        events: 3,
        score_mean: 0.5,
        score_stddev: 0,
        score_minimum: 0.5,
        score_maximum: 0.5,
        score_histogram:
        {
          bins: sparse_bins(49 => 3),
          maximum: 0.5,
          minimum: 0.5,
          underflow: 0,
          overflow: 0
        }
      }
    ]
  end

  before do
    records.each do |rec|
      recording = create(:audio_recording, site: site, creator: writer_user)

      rec[:tag_ids]&.zip(rec[:scores], rec[:provenances])&.each do |tag_index, score, provenance_index|
        create(
          :audio_event_using_tag,
          audio_recording: recording,
          creator: writer_user,
          tag: tags[tag_index],
          score: score,
          provenance: provenance_index ? provenances[provenance_index] : nil
        )
      end
    end

    # create an audio_event that writer_user has no access to, to prove it is not included in the counts
    create(:audio_event_with_tags)
  end

  it 'returns the correct summary data' do
    post '/reports/event_summaries', params: { filter: {} }, **api_headers(writer_token)
    expect_success

    expect(api_data).to match(array_including(expected_data))
  end

  context 'with filter by tag' do
    it 'returns the correct summary data, excluding the filtered tag id' do
      body = { filter: { 'tags.id': { not_eq: tags[3].id } } }

      post '/reports/event_summaries', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match(array_including(expected_data[0..3]))
    end
  end

  # Build a 50-element bins array from a sparse {index => count} hash
  def sparse_bins(index_values)
    Array.new(50, 0).tap { |bins| index_values.each { |index, count| bins[index] = count } }
  end
end
