# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'perch format' do
    let(:perch) {
      <<~CSV
        filename,start_offset_seconds,end_offset_seconds,label,score
        tests/files/audio/100sec.wav,20.0,25.0,negative,12.739699
        tests/files/audio/100sec.wav,0.0,5.0,wascawwy wabbit,-11.764339
        tests/files/audio/100sec.wav,5.0,10.0,wascawwy wabbit,-14.89451
        tests/files/audio/100sec.wav,5.0,10.0,mgw,-15.89451
      CSV
    }

    let(:perch_basename) {
      "#{audio_recording.friendly_name}.csv"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      expect(parser.parse_and_commit(perch, perch_basename)).to be_success

      results = parser.serialize_audio_events

      expect(results.size).to be(4)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2, r3, r4]

      common = {
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty)
      }

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 20.0,
        end_time_seconds: 25.0,
        score: 12.739699,
        import_file_index: 0
      ))

      expect(r2).to match(a_hash_including(
        **common,
        start_time_seconds: 0.0,
        end_time_seconds: 5.0,
        score: -11.764339,
        import_file_index: 1
      ))

      expect(r3).to match(a_hash_including(
        **common,
        start_time_seconds: 5.0,
        end_time_seconds: 10.0,
        score: -14.89451,
        import_file_index: 2
      ))

      expect(r4).to match(a_hash_including(
        **common,
        start_time_seconds: 5.0,
        end_time_seconds: 10.0,
        score: -15.89451,
        import_file_index: 3
      ))

      expect(results.pluck(:tags).flatten.pluck(:text)).to eq [
        'negative',
        'wascawwy wabbit',
        'wascawwy wabbit',
        'mgw'
      ]
    end
  end
end
