# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'importing JCU csv' do
    let(:jcu) {
      <<~CSV
        Start,End,TP,model,File,Site,Time,Date,RecordingID,Label
        1938,1941,0.140024634,BTF_glm_20240910,20240310T153736+1000_BAR-01_1771728.rds,BAR-01,10/03/2024 16:09,10/03/2024,#{audio_recording.id},birb
        705,708,0.565514083,BTF_glm_20240910,20240310T163713+1000_BAR-03_1772047.rds,BAR-03,10/03/2024 16:48,10/03/2024,#{another_recording.id},good boi
        1479,1482,0.250343977,BTF_glm_20240910,20240310T163713+1000_BAR-03_1772047.rds,BAR-03,10/03/2024 17:01,10/03/2024,#{another_recording.id},birb
      CSV
    }

    let(:jcu_basename) {
      "#{audio_recording.friendly_name}.csv"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(jcu, jcu_basename)

      results = parser.serialize_audio_events

      expect(results.size).to be(3)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2, r3]

      common = {
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        # channel: nil,
        # low_frequency_hertz: nil,
        # high_frequency_hertz: nil,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty)
      }

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 1938.0,
        end_time_seconds: 1941.0,
        score: 0.140024634,
        audio_recording_id: audio_recording.id,
        import_file_index: 0
      ))

      expect(r2).to match(a_hash_including(
        **common,
        start_time_seconds: 705,
        end_time_seconds: 708,
        score: 0.565514083,
        audio_recording_id: another_recording.id,
        import_file_index: 1
      ))

      expect(r3).to match(a_hash_including(
        **common,
        start_time_seconds: 1479,
        end_time_seconds: 1482,
        score: 0.250343977,
        audio_recording_id: another_recording.id,
        import_file_index: 2
      ))

      expect(results.pluck(:tags).flatten.pluck(:text)).to eq ['birb', 'good boi', 'birb']
    end
  end
end
