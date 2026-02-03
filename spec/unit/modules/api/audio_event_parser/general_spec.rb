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

    # https://github.com/QutEcoacoustics/baw-server/issues/891
    it 'handles race condition when another job creates a tag with the same text during import' do
      parser = Api::AudioEventParser.new(import_file, writer_user, audio_recording:)

      csv = <<~CSV
        file path,channel,start time,end time,tag,score
        tests/files/audio/100sec.wav,1,20.0,25.0,brand_new_tag,0.9
      CSV
      filename = 'test.csv'

      # Intercept parse to simulate another job creating the tag after parsing
      # but before the tags are saved (the race condition window)
      existing_tag = nil
      allow(parser).to receive(:parse).and_wrap_original do |method, *args, **kwargs|
        result = method.call(*args, **kwargs)

        return result unless result.success?

        # After parse completes, simulate another job creating the same tag
        # This is the race condition - the tag didn't exist when we parsed,
        # but now exists when we try to save.
        existing_tag = Tag.create!(text: 'brand_new_tag', creator: writer_user)

        result
      end

      result = parser.parse_and_commit(csv, filename)

      aggregate_failures do
        expect(result).to be_success

        events = parser.serialize_audio_events
        expect(events.size).to eq(1)
        expect(events.first[:tags].pluck(:text)).to include('brand_new_tag')

        # Verify only one tag exists (the existing one, not a duplicate)
        expect(Tag.where('LOWER(text) = ?', 'brand_new_tag').count).to eq(1)

        # Verify the tagging uses the existing tag's id
        audio_event = AudioEvent.find(events.first[:id])
        expect(audio_event.tags).to include(existing_tag)
      end
    end
  end
end
