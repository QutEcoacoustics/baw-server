# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'importing AP json' do
    let(:ap_json) {
      <<~JSON
        [
          {
            "EventEndSeconds": 47.72861678004535,
            "HighFrequencyHertz": 8200.0,
            "LowFrequencyHertz": 5800.0,
            "EventDurationSeconds": 0.44117913832199207,
            "BandWidthHertz": 2400.0,
            "Name": "Tyto tenebricosa",
            "Profile": "TrillMidUShape",
            "DecibelDetectionThreshold": 9.0,
            "ComponentName": "SpectralEvent",
            "ResultStartSeconds": 47.28743764172336,
            "Score": 0.0,
            "ScoreRange": "[0.000, 0.000)",
            "ScoreNormalized": "NaN",
            "SegmentStartSeconds": 0.0,
            "EventStartSeconds": 47.28743764172336,
            "FileName": "3_0-1min",
            "SegmentDurationSeconds": 60.0,
            "ResultMinute": 0
          },
          {
            "HarmonicInterval": 1292.7592162126768,
            "EventEndSeconds": 52.128798185941044,
            "HighFrequencyHertz": 6500.0,
            "LowFrequencyHertz": 1200.0,
            "EventDurationSeconds": 2.6935147392290233,
            "BandWidthHertz": 5300.0,
            "Name": "Tyto tenebricosa",
            "Profile": "Screech",
            "DecibelDetectionThreshold": 12.0,
            "ComponentName": "HarmonicEvent",
            "ResultStartSeconds": 49.43528344671202,
            "Score": 0.5248084955106175,
            "ScoreRange": "[0.000, 1.500)",
            "ScoreNormalized": 0.34987233034041165,
            "SegmentStartSeconds": 0.0,
            "EventStartSeconds": 49.43528344671202,
            "FileName": "3_0-1min",
            "SegmentDurationSeconds": 60.0,
            "ResultMinute": 0
          }
        ]
      JSON
    }

    let(:ap_json_basename) {
      "#{audio_recording.friendly_name}__QUT.MultiRecognizer.Events.beta.json"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(ap_json, ap_json_basename)

      results = parser.serialize_audio_events

      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2]

      expect(r1).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        start_time_seconds: be_within(0.001).of(47.28743764172336),
        end_time_seconds: be_within(0.001).of(47.72861678004535),
        low_frequency_hertz: 5800.0,
        high_frequency_hertz: 8200.0,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty),
        import_file_index: 0,
        score: 0.0
      ))

      expect(r1[:tags]).to match([
        a_hash_including(
          text: 'Tyto tenebricosa'
        )
      ])

      expect(r2).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        start_time_seconds: be_within(0.001).of(49.43528344671202),
        end_time_seconds: be_within(0.001).of(52.12879818594104),
        low_frequency_hertz: 1200.0,
        high_frequency_hertz: 6500.0,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty),
        import_file_index: 1,
        score: be_within(0.001).of(0.5248084955106175)
      ))

      expect(r2[:tags]).to match([
        a_hash_including(
          text: 'Tyto tenebricosa'
        )
      ])

      # test object equivalence - we shouldn't be creating duplicate new tags
      expect(r1[:tags].first).to eq r2[:tags].first
    end
  end
end
