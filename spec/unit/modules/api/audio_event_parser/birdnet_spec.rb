# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'birdnet format' do
    let(:birdnet) {
      <<~CSV
        Start (s),End (s),Scientific name,Common name,Confidence,File
        4.0,7.0,Todiramphus sacer,Pacific Kingfisher,0.2574,/data/source/5min.wav
        52.0,55.0,Todiramphus sacer,Pacific Kingfisher,0.3064,/data/source/5min.wav
        108.0,111.0,Xanthotis macleayanus,Macleay's Honeyeater,0.5350,/data/source/5min.wav
        284.0,287.0,Chrysococcyx minutillus,Little Bronze-Cuckoo,0.2173,/data/source/5min.wav
      CSV
    }

    let(:birdnet_basename) {
      "#{audio_recording.friendly_name}.BirdNET.csv"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(birdnet, birdnet_basename)

      results = parser.serialize_audio_events

      results => [r1, r2, r3, r4]

      common = {
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty)
      }

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 4.0,
        end_time_seconds: 7.0,
        score: 0.2574,
        import_file_index: 0,
        tags: a_collection_including(
          a_hash_including(text: 'Pacific Kingfisher'),
          a_hash_including(text: 'Todiramphus sacer')
        )
      ))

      expect(r2).to match(a_hash_including(
        **common,
        start_time_seconds: 52.0,
        end_time_seconds: 55.0,
        score: 0.3064,
        import_file_index: 1,
        tags: a_collection_including(
          a_hash_including(text: 'Pacific Kingfisher'),
          a_hash_including(text: 'Todiramphus sacer')
        )
      ))

      expect(r3).to match(a_hash_including(
        **common,
        start_time_seconds: 108.0,
        end_time_seconds: 111.0,
        score: 0.5350,
        import_file_index: 2,
        tags: a_collection_including(
          a_hash_including(text: "Macleay's Honeyeater"),
          a_hash_including(text: 'Xanthotis macleayanus')
        )
      ))

      expect(r4).to match(a_hash_including(
        **common,
        start_time_seconds: 284.0,
        end_time_seconds: 287.0,
        score: 0.2173,
        import_file_index: 3,
        tags: a_collection_including(
          a_hash_including(text: 'Little Bronze-Cuckoo'),
          a_hash_including(text: 'Chrysococcyx minutillus')
        )
      ))

      # the two events with the same tags should have the same tag objects
      expect(r1[:tags].first[:id]).to be(r2[:tags].first[:id])
      expect(r1[:tags].second[:id]).to be(r2[:tags].second[:id])
    end
  end
end
