require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'rejections' do
    let(:csv) {
      <<~CSV
        audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,score,tag
        #{audio_recording.id},0,1,100,500,0.5,crickets
        #{audio_recording.id},2,3,150,550,0.4,birb
        #{audio_recording.id},4,5,200,600,0,frog
        #{another_recording.id},6,7,250,650,0.8,insect
      CSV
    }

    def expect_updated_stats(imported:, parsed:)
      import_file.reload
      expect(import_file.parsed_count).to eq parsed
      expect(import_file.imported_count).to eq imported
    end

    context 'with a score_minimum' do
      it 'rejects events below the threshold or with missing score while accepting others' do
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering: Api::AudioEventParser::FilteringParameters.new(score_minimum: 0.5)
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 4

        # scores greater than or equal to score_minimum are accepted
        expect(serialized[0]).to match(a_hash_including(
          id: a_kind_of(Integer),
          rejections: []
        ))
        expect(serialized[1]).to match(a_hash_including(
          id: nil,
          rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]
        ))
        expect(serialized[2]).to match(a_hash_including(
          id: nil,
          rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]
        ))
        expect(serialized[3]).to match(a_hash_including(
          id: a_kind_of(Integer),
          rejections: []
        ))

        # Only 2 events saved
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 2

        # And just 1 new tag was added
        new_tag = Tag.find_by(text: 'insect')
        expect(new_tag).to be_present
        expect(serialized[3][:tags].filter { |t| t[:text] == 'insect' }.first[:id]).to eq new_tag.id

        expect(Tag.find_by(text: 'birb')).to be_nil
        expect(Tag.find_by(text: 'frog')).to be_nil

        expect_updated_stats(imported: 2, parsed: 4)
      end

      it 'fails the import when all events are rejected' do
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering: Api::AudioEventParser::FilteringParameters.new(score_minimum: 20.0)
        )
        result = parser.parse_and_commit(csv, 'all_rejected.csv')

        expect(result).to be_failure.and(have_attributes(failure: 'All events were rejected'))

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 4
        expect(serialized).to all(match(a_hash_including(
          id: nil,
          rejections: [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM }]
        )))

        # No events saved
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 0

        # it was not saved
        expect_updated_stats(imported: 0, parsed: 0)
      end

      it 'score becomes a required field for a file if a minimum is set' do
        csv = <<~CSV
          audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
          #{audio_recording.id},0,1,100,500,crickets
        CSV

        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering: Api::AudioEventParser::FilteringParameters.new(score_minimum: 0.5)
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_failure.and(have_attributes(failure: 'Validation failed'))

        serialized = parser.serialize_audio_events
        expect(serialized).to match([
          a_hash_including(
            id: nil,
            errors: [
              { score: ['is missing and required when importing with a minimum score threshold or top N filtering'] }
            ]
          )
        ])
      end

      it 'score becomes a required field for an event if a minimum is set' do
        csv = <<~CSV
          audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag,score
          #{audio_recording.id},0,1,100,500,crickets,25
          #{audio_recording.id},0,1,100,500,crickets,
        CSV

        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering: Api::AudioEventParser::FilteringParameters.new(score_minimum: 0.5)
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_failure.and(have_attributes(failure: 'Validation failed'))

        serialized = parser.serialize_audio_events
        expect(serialized).to match([
          a_hash_including(errors: [], rejections: []),
          a_hash_including(
            id: nil,
            errors: [
              { score: ['is missing and required when importing with a minimum score threshold or top N filtering'] }
            ]
          )
        ])
      end
    end

    context 'without a score_minimum' do
      it 'does not reject any events even if scores are low or missing' do
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          filtering: Api::AudioEventParser::FilteringParameters.new(score_minimum: nil)
        )
        result = parser.parse_and_commit(csv, 'test.csv')

        expect(result).to be_success

        serialized = parser.serialize_audio_events
        expect(serialized.size).to eq 4

        expect(serialized).to all(match(a_hash_including(
          id: a_kind_of(Integer),
          rejections: []
        )))

        # All 4 events saved
        expect(AudioEvent.where(audio_event_import_file_id: import_file.id).count).to eq 4

        # And 3 new tags were added ('crickets' was already present)
        expect(Tag.where(text: ['insect', 'birb', 'frog']).count).to eq 3

        expect_updated_stats(imported: 4, parsed: 4)
      end
    end
  end
end
