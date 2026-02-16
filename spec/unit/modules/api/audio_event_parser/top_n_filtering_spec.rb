# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'top N per T filtering' do
    let(:csv) {
      <<~CSV
        audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,score,tag
        #{audio_recording.id},0,1,100,500,0.9,bird
        #{audio_recording.id},1,2,100,500,0.8,bird
        #{audio_recording.id},2,3,100,500,0.7,bird
        #{audio_recording.id},10,11,100,500,0.95,bird
        #{audio_recording.id},11,12,100,500,0.85,bird
        #{audio_recording.id},12,13,100,500,0.75,bird
        #{audio_recording.id},0,1,200,600,0.6,frog
        #{audio_recording.id},1,2,200,600,0.5,frog
        #{audio_recording.id},10,11,200,600,0.7,frog
      CSV
    }

    def expect_updated_stats(imported:, parsed:, include_top:, include_top_per:)
      import_file.reload
      expect(import_file.parsed_count).to eq parsed
      expect(import_file.imported_count).to eq imported
      expect(import_file.include_top).to eq include_top
      expect(import_file.include_top_per).to eq include_top_per
    end

    context 'with top N filtering enabled' do
      it 'keeps only top N events per tag per time interval' do
        # Top 2 per 10 second interval
        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 2,
          include_top_per: 10
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 9

        # Compact assertions - check all 9 events
        expect(serialized).to match([
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.9
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.8
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]), # bird 0.7 rejected
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.95
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.85
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]), # bird 0.75 rejected
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # frog 0.6
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # frog 0.5
          a_hash_including(id: a_kind_of(Integer), rejections: [])   # frog 0.7
        ])

        # 7 events should be saved (top 2 per interval for bird in 2 intervals + 2 frogs in first interval + 1 frog in second interval)
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 7

        expect_updated_stats(imported: 7, parsed: 9, include_top: 2, include_top_per: 10)
      end

      it 'works with top 1 filtering' do
        # Top 1 per 10 second interval
        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 1,
          include_top_per: 10
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 9

        # Check all 9 events - only highest in each interval/tag kept
        expect(serialized).to match([
          a_hash_including(id: a_kind_of(Integer), rejections: []), # bird 0.9 - top in interval
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]),  # bird 0.8 rejected
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]),  # bird 0.7 rejected
          a_hash_including(id: a_kind_of(Integer), rejections: []), # bird 0.95 - top in interval
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]),  # bird 0.85 rejected
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]),  # bird 0.75 rejected
          a_hash_including(id: a_kind_of(Integer), rejections: []), # frog 0.6 - top in interval
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_NOT_IN_TOP_N }]), # frog 0.5 rejected
          a_hash_including(id: a_kind_of(Integer), rejections: []) # frog 0.7 - top in interval
        ])

        # 4 events should be saved (1 bird per interval * 2 intervals + 1 frog per interval * 2 intervals)
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 4

        expect_updated_stats(imported: 4, parsed: 9, include_top: 1, include_top_per: 10)
      end

      it 'works with include_top alone (no time interval)' do
        # Top 2 overall per tag (no time subdivision)
        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 2,
          include_top_per: nil
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 9

        # For bird tag: top 2 overall are 0.95 (index 3) and 0.9 (index 0)
        # For frog tag: top 2 overall are 0.7 (index 8) and 0.6 (index 6)
        # So we expect 4 events total

        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 4

        expect_updated_stats(imported: 4, parsed: 9, include_top: 2, include_top_per: nil)
      end

      it 'combines with score filtering using AND logic' do
        # Top 2 per 10 second interval AND score >= 0.8
        filtering = Api::AudioEventParser::FilteringParameters.new(
          score_minimum: 0.8,
          include_top: 2,
          include_top_per: 10
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events

        # Compact all assertions
        expect(serialized).to match([
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.9 passes both
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.8 passes both
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]), # bird 0.7 fails score
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.95 passes both
          a_hash_including(id: a_kind_of(Integer), rejections: []),  # bird 0.85 passes both
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]),  # bird 0.75 fails score
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]),  # frog 0.6 fails score
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]),  # frog 0.5 fails score
          a_hash_including(id: nil, rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }])   # frog 0.7 fails score
        ])

        # 4 events should be saved (top 2 birds per interval that also pass score filter)
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 4
      end

      it 'is an invalid file without scores when top N filtering is enabled' do
        csv_no_scores = <<~CSV
          audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
          #{audio_recording.id},0,1,100,500,bird
          #{audio_recording.id},1,2,100,500,bird
        CSV

        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 1,
          include_top_per: 10
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv_no_scores, 'test.csv')

        expect(result).to be_failure.and(have_attributes(
          failure: 'Validation failed'
        ))

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 2

        # Both events are rejected because they don't have scores
        # When top N filtering is enabled, events without scores are rejected
        expect(serialized).to all(match(a_hash_including(
          id: nil,
          errors: [
            { score: ['is missing and required when importing with a minimum score threshold or top N filtering'] }
          ]
        )))

        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 0
      end

      it 'an event is invalid without a score when top N filtering is enabled' do
        csv_no_scores = <<~CSV
          audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag,score
          #{audio_recording.id},0,1,100,500,bird,0.5
          #{audio_recording.id},1,2,100,500,bird,
        CSV

        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 1,
          include_top_per: 10
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv_no_scores, 'test.csv')

        expect(result).to be_failure.and(have_attributes(
          failure: 'Validation failed'
        ))

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 2

        # Both events are rejected because they don't have scores
        # When top N filtering is enabled, events without scores are rejected
        expect(serialized).to match([
          a_hash_including(
            errors: [],
            rejections: []
          ),
          a_hash_including(
            id: nil,
            errors: [
              { score: ['is missing and required when importing with a minimum score threshold or top N filtering'] }
            ]
          )
        ])

        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 0
      end
    end

    context 'without top N filtering' do
      it 'does not reject any events when filtering is disabled' do
        filtering = Api::AudioEventParser::FilteringParameters.new
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 9

        expect(serialized).to all(match(a_hash_including(
          id: a_kind_of(Integer),
          rejections: []
        )))

        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 9

        expect_updated_stats(imported: 9, parsed: 9, include_top: nil, include_top_per: nil)
      end
    end

    context 'validation' do
      it 'allows include_top alone' do
        filtering = Api::AudioEventParser::FilteringParameters.new(
          include_top: 2,
          include_top_per: nil
        )
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering:
        )

        expect(parser).to be_a(Api::AudioEventParser)
      end

      it 'raises an error if only include_top_per is provided' do
        expect {
          Api::AudioEventParser::FilteringParameters.new(
            include_top: nil,
            include_top_per: 10
          )
        }.to raise_error('include_top_per can only be set when include_top is also set')
      end
    end
  end
end
