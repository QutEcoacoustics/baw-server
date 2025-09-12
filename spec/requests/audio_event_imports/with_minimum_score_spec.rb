# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe '/audio_event_imports' do
  include_context 'with audio event import context'

  let(:birdnet_example) {
    f = temp_file(basename: raven_filename)
    f.write <<~CSV
      Start (s),End (s),Scientific name,Common name,Confidence,File
      4.0,7.0,Todiramphus sacer,Pacific Kingfisher,0.2574,/data/source/5min.wav
      52.0,55.0,Todiramphus sacer,Pacific Kingfisher,0.3064,/data/source/5min.wav
      108.0,111.0,Xanthotis macleayanus,Macleay's Honeyeater,0.5350,/data/source/5min.wav
      284.0,287.0,Chrysococcyx minutillus,Little Bronze-Cuckoo,0.2173,/data/source/5min.wav
    CSV
    f
  }

  [true, false].each do |commit|
    describe "(with commit: #{commit})" do
      it 'can do an import with score filtering' do
        create_import
        submit(birdnet_example, commit:, minimum_score: 0.5)

        score_rejection = [{ score: Api::AudioEventParser::REJECTION_SCORE_BELOW_MINIMUM.to_s }]
        assert_success(committed: commit, name: raven_filename, minimum_score: 0.5, imported_count: commit ? 1 : 0, parsed_events: [
          a_hash_including(
            id: nil,
            errors: [],
            rejections: score_rejection,
            score: 0.2574
          ),
          a_hash_including(
            id: nil,
            errors: [],
            rejections: score_rejection,
            score: 0.3064
          ),
          a_hash_including(
            id: commit ? a_kind_of(Integer) : nil,
            errors: [],
            rejections: [],
            score: 0.5350
          ),
          a_hash_including(
            id: nil,
            errors: [],
            rejections: score_rejection,
            score: 0.2173
          )
        ])
      end
    end
  end
end
