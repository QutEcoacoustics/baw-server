# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe '/audio_event_imports' do
  include_context 'with audio event import context'

  let(:top_n_example) {
    f = temp_file(basename: 'top_n_events.csv')
    f.write <<~CSV
      audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,score,tag
      #{audio_recording.id},0,1,100,500,0.9,bird
      #{audio_recording.id},1,2,100,500,0.8,bird
      #{audio_recording.id},2,3,100,500,0.7,bird
      #{audio_recording.id},10,11,100,500,0.95,bird
      #{audio_recording.id},11,12,100,500,0.85,bird
      #{audio_recording.id},12,13,100,500,0.75,bird
    CSV
    f
  }

  [true, false].each do |commit|
    describe "(with commit: #{commit})" do
      it 'can do an import with top N filtering' do
        create_import
        # Top 2 per 10 second interval
        submit(top_n_example, commit:, include_top: 2, include_top_per: 10)

        top_n_rejection = [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N.to_s }]
        assert_success(
          committed: commit,
          name: 'top_n_events.csv',
          include_top: 2,
          include_top_per: 10,
          imported_count: commit ? 4 : 0,
          parsed_events: [
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.9),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.8),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.7),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.95),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.85),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.75)
          ]
        )
      end

      it 'can do an import with top 1 filtering' do
        create_import
        # Top 1 per 10 second interval
        submit(top_n_example, commit:, include_top: 1, include_top_per: 10)

        top_n_rejection = [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N.to_s }]
        assert_success(
          committed: commit,
          name: 'top_n_events.csv',
          include_top: 1,
          include_top_per: 10,
          imported_count: commit ? 2 : 0,
          parsed_events: [
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.9),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.8),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.7),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.95),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.85),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.75)
          ]
        )
      end

      it 'can do an import with include_top only (no interval subdivision)' do
        create_import
        # Top 2 overall (no per-interval subdivision)
        # With no interval subdivision, all events are in one bucket
        # So keep top 2 scores: 0.95, 0.9
        submit(top_n_example, commit:, include_top: 2)

        top_n_rejection = [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N.to_s }]
        assert_success(
          committed: commit,
          name: 'top_n_events.csv',
          include_top: 2,
          include_top_per: nil,
          imported_count: commit ? 2 : 0,
          parsed_events: [
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.9),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.8),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.7),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.95),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.85),
            a_hash_including(id: nil, errors: [], rejections: top_n_rejection, score: 0.75)
          ]
        )
      end

      it 'can combine top N filtering with minimum score' do
        create_import
        # Top 2 per 10 second interval, with minimum score of 0.8
        submit(top_n_example, commit:, include_top: 2, include_top_per: 10, minimum_score: 0.8)

        score_rejection = [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM.to_s }]
        assert_success(
          committed: commit,
          name: 'top_n_events.csv',
          include_top: 2,
          include_top_per: 10,
          minimum_score: 0.8,
          imported_count: commit ? 4 : 0,
          parsed_events: [
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.9),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.8),
            a_hash_including(id: nil, errors: [], rejections: score_rejection, score: 0.7),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.95),
            a_hash_including(id: commit ? a_kind_of(Integer) : nil, errors: [], rejections: [], score: 0.85),
            a_hash_including(id: nil, errors: [], rejections: score_rejection, score: 0.75)
          ]
        )
      end
    end
  end
end
