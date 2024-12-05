# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'Raven files' do
    let(:raven) {
      <<~FILE
        Selection\tView\tChannel\tBegin Time (s)\tEnd Time (s)\tLow Freq (Hz)\tHigh Freq (Hz)\tDelta Time (s)\tDelta Freq (Hz)\tAvg Power Density (dB FS/Hz)\tAnnotation
        1\tWaveform 1\t1\t6.709509878\t15.096397225\t1739.012\t3798.813\t8.3869\t2059.801\t\tBirb
        1\tSpectrogram 1\t1\t6.709509878\t15.096397225\t1739.012\t3798.813\t8.3869\t2059.801\t-75.87\tBirb
        2\tWaveform 1\t1\t29.383026016\t40.257059266\t1587.060\t4136.485\t10.8740\t2549.426\t\tdonkey
        2\tSpectrogram 1\t1\t29.383026016\t40.257059266\t1587.060\t4136.485\t10.8740\t2549.426\t-75.64\tdonkey
      FILE
    }

    let(:raven_basename) {
      "#{audio_recording.friendly_name}.Table.1.selections.txt"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse(raven, raven_basename)

      results = parser.serialize_audio_events

      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2]

      expect(r1).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: be_within(0.001).of(6.709509878),
        end_time_seconds: be_within(0.001).of(15.096397225),
        low_frequency_hertz: be_within(0.001).of(1739.012),
        high_frequency_hertz: be_within(0.001).of(3798.813),
        id: nil
      ))

      expect(r1[:tags]).to match([
        a_hash_including(
          text: 'Birb'
        )
      ])

      expect(r2).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: be_within(0.001).of(29.383026016),
        end_time_seconds: be_within(0.001).of(40.257059266),
        low_frequency_hertz: be_within(0.001).of(1587.060),
        high_frequency_hertz: be_within(0.001).of(4136.485),
        id: nil
      ))

      expect(r2[:tags]).to match([
        a_hash_including(
          text: 'donkey'
        )
      ])
    end
  end
end
