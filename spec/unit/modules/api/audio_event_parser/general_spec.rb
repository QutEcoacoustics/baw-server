# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'edge cases' do
    it 'does not attempt to parse a Recording column as if it were RecordingId' do
      transformer = Api::AudioEventParser::KeyTransformer.new(:audio_recording_id, :recording_id, :RecordingID)

      values = {
        Recording: '20240921T013002+1000_Station-01_2505488.txt'
      }

      result = transformer.extract_key(values)

      expect(result).to eq(Dry::Monads::Maybe::None.instance)
    end

    it 'does not parse parts of an invalid integer string as a recording id' do
      parser = Api::AudioEventParser.new(import_file, reader_user)

      csv = <<~CSV
        file path,channel,start time,end time,tag,score
        tests/files/audio/100sec.wav,1,20.0,25.0,negative,12.739699
      CSV
      filename = 'abc.csv'
      result = parser.parse(csv, filename)

      expect(result).to be_failure.and(have_attributes(failure: 'Validation failed'))

      events = parser.serialize_audio_events

      expect(events.first).to match(a_hash_including(
        errors: [
          {
            audio_recording_id: ['must be an integer']
          }
        ]
      ))
    end

    [true, false].each do |value|
      it "automatically de-duplicates tags (commit=#{value})" do
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          additional_tags: [tag_crickets, tag_crickets]
        )

        csv = <<~CSV
          file path,channel,start time,end time,tag,score
          tests/files/audio/100sec.wav,1,20.0,25.0,negative;crickets;koala;crickets,12.739699
        CSV
        filename = audio_recording.friendly_name

        result = value ? parser.parse_and_commit(csv, filename) : parser.parse(csv, filename)

        aggregate_failures do
          expect(result).to be_success
          events = parser.serialize_audio_events

          expect(events.size).to eq(1)
          expect(events.first[:tags].pluck(:text)).to match(a_collection_containing_exactly('negative', 'crickets',
            'koala'))
        end
      end
    end
  end
end
