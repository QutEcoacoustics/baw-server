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

    # This one is tricky because they abused the raven format.
    # So normally Offset represents the start time, it wasn't used here, and we
    # should instead be using Start and End.
    let!(:jcu_2) {
      <<~CSV
        IN FILE,CHANNEL,OFFSET,DURATION,MANUAL ID,INDIR,Start,End,ABC_ABC_lab_001122,Recording,RecordingID,Date,Time,AudioLink,PlayLink
        1.flac,0,0,10,,C:/Users/FakeUser/Documents/in,0,19.4815,3.14159,#{audio_recording.friendly_name},#{audio_recording.id},1/09/2019,1/09/2019,https://api.acousticobservatory.org/audio_recordings/2204/media.flac?start_offset=0&end_offset=19.4815,https://data.acousticobservatory.org/listen/2204?start=0&end=30
        2.flac,0,0,10,,C:/Users/FakeUser/Documents/in,150,179.8376,2.71828,#{another_recording.friendly_name},#{another_recording.id},24/07/2019,24/07/2019 18:00,https://api.acousticobservatory.org/audio_recordings/1154/media.flac?start_offset=150.0&end_offset=179.8376,https://data.acousticobservatory.org/listen/1154?start=150&end=180
        21.flac,0,0,10,,C:/Users/FakeUser/Documents/in,61279.97338,61380.23303,346.249775,20190901T180000+1000_REC.flac,#{another_recording.id},1/09/2019,1/09/2019,https://api.acousticobservatory.org/audio_recordings/2204/media.flac?start_offset=0&end_offset=19.4821,https://data.acousticobservatory.org/listen/2204?start=0&end=36
      CSV
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

    it 'can parse events with a different format' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(jcu_2, 'jcu_2.csv')

      results = parser.serialize_audio_events

      expect(results.size).to be(3)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2, r3]

      common = {
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        channel: 0,
        #score: nil,
        # low_frequency_hertz: nil,
        # high_frequency_hertz: nil,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty)
      }

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 0,
        end_time_seconds: 19.4815,
        audio_recording_id: audio_recording.id,
        import_file_index: 0
      ))

      expect(r2).to match(a_hash_including(
        **common,
        start_time_seconds: 150,
        end_time_seconds: 179.8376,
        audio_recording_id: another_recording.id,
        import_file_index: 1
      ))

      expect(r3).to match(a_hash_including(
        **common,
        start_time_seconds: 61_279.97338,
        end_time_seconds: 61_380.23303,
        audio_recording_id: another_recording.id,
        import_file_index: 2
      ))

      expect(results.pluck(:tags).flatten.pluck(:text)).to eq []
    end
  end
end
