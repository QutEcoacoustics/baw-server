# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'lance format' do
    let(:lance) {
      <<~CSV
        file path,channel,start time,end time,tag,score
        tests/files/audio/100sec.wav,1,20.0,25.0,negative,12.739699
      CSV
    }

    let(:lance_basename) {
      "#{audio_recording.friendly_name}.csv"
    }

    let(:lance_tsv) {
      <<~CSV
        file path\tchannel\tstart time\tend time\ttag\tscore
        tests/files/audio/100sec.wav\t1\t20.0\t25.0\tcricket\t12.739699
      CSV
    }

    let(:lance_tsv_basename) {
      "#{audio_recording.friendly_name}.tsv"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(lance, lance_basename)

      results = parser.serialize_audio_events

      results => [r1]

      expect(r1).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: 20.0,
        end_time_seconds: 25.0,
        id: an_instance_of(Integer),
        score: 12.739699,
        errors: an_instance_of(Array).and(be_empty)
      ))

      expect(r1[:tags]).to match([
        a_hash_including(
          text: 'negative'
        )
      ])
    end

    it 'can parse events from tsv' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(lance_tsv, lance_tsv_basename)

      results = parser.serialize_audio_events

      expect(results.size).to be(1)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1]

      expect(r1).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: 20.0,
        end_time_seconds: 25.0,
        id: an_instance_of(Integer),
        score: 12.739699,
        errors: an_instance_of(Array).and(be_empty)
      ))

      expect(r1[:tags]).to match([
        a_hash_including(
          text: 'cricket'
        )
      ])
    end
  end
end
