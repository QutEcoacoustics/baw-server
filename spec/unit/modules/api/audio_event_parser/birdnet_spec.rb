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

    context 'with failing production test case #890' do
      # https://github.com/QutEcoacoustics/baw-server/issues/890
      # This turned out to be a dud issue, but leaving the test data for robustness anyway
      let(:birdnet2) {
        <<~CSV
          Start (s),End (s),Scientific name,Common name,Confidence,File
          0,3.0,Melithreptus albogularis,White-throated Honeyeater,0.3482,/data/input/20250618T230000Z_NR2_5133298.wav
          0,3.0,Malurus melanocephalus,Red-backed Fairywren,0.2689,/data/input/20250618T230000Z_NR2_5133298.wav
          105.0,108.0,Actitis hypoleucos,Common Sandpiper,0.3960,/data/input/20250618T230000Z_NR2_5133298.wav
          108.0,111.0,Actitis hypoleucos,Common Sandpiper,0.5048,/data/input/20250618T230000Z_NR2_5133298.wav
          336.0,339.0,Philemon citreogularis,Little Friarbird,0.4564,/data/input/20250618T230000Z_NR2_5133298.wav
          423.0,426.0,Philemon citreogularis,Little Friarbird,0.2787,/data/input/20250618T230000Z_NR2_5133298.wav
          444.0,447.0,Philemon citreogularis,Little Friarbird,0.2869,/data/input/20250618T230000Z_NR2_5133298.wav
          570.0,573.0,Corvus orru,Torresian Crow,0.5258,/data/input/20250618T230000Z_NR2_5133298.wav
          921.0,924.0,Corvus orru,Torresian Crow,0.8734,/data/input/20250618T230000Z_NR2_5133298.wav
          1158.0,1161.0,Actitis hypoleucos,Common Sandpiper,0.2528,/data/input/20250618T230000Z_NR2_5133298.wav
          1224.0,1227.0,Melithreptus albogularis,White-throated Honeyeater,0.2569,/data/input/20250618T230000Z_NR2_5133298.wav
          1227.0,1230.0,Melithreptus albogularis,White-throated Honeyeater,0.3524,/data/input/20250618T230000Z_NR2_5133298.wav
          1257.0,1260.0,Grallina cyanoleuca,Magpie-lark,0.5610,/data/input/20250618T230000Z_NR2_5133298.wav
          1272.0,1275.0,Grallina cyanoleuca,Magpie-lark,0.9777,/data/input/20250618T230000Z_NR2_5133298.wav
          1512.0,1515.0,Pardalotus striatus,Striated Pardalote,0.8286,/data/input/20250618T230000Z_NR2_5133298.wav
          1884.0,1887.0,Philemon citreogularis,Little Friarbird,0.6711,/data/input/20250618T230000Z_NR2_5133298.wav
          1896.0,1899.0,Philemon citreogularis,Little Friarbird,0.2864,/data/input/20250618T230000Z_NR2_5133298.wav
          2424.0,2427.0,Cracticus torquatus,Gray Butcherbird,0.3658,/data/input/20250618T230000Z_NR2_5133298.wav
          2484.0,2487.0,Gavicalis virescens,Singing Honeyeater,0.3304,/data/input/20250618T230000Z_NR2_5133298.wav
          3555.0,3558.0,Melithreptus albogularis,White-throated Honeyeater,0.4089,/data/input/20250618T230000Z_NR2_5133298.wav
        CSV
      }

      let(:birdnet2_basename) {
        'BirdNET.results.csv'
      }

      it 'can parse events from another birdnet file' do
        parser = Api::AudioEventParser.new(
          import_file,
          writer_user,
          provenance:,
          audio_recording:,
          score_minimum: 0.5
        )

        result = parser.parse_and_commit(birdnet2, birdnet2_basename)

        expect(result).to be_success.and(have_attributes(failure: nil))

        results = parser.serialize_audio_events

        expect(results.length).to eq(20)
        expect(results.filter { _1[:rejections].any? }.count).to eq 13
        expect(results.filter { _1[:rejections].empty? }.count).to eq 7
      end
    end
  end
end
