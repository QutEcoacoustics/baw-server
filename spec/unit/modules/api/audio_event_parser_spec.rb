# frozen_string_literal: true

describe Api::AudioEventParser do
  create_entire_hierarchy

  let(:import) { create(:audio_event_import) }

  let(:notes) {
    {
      'created' => { 'message' => 'Created via audio event import', 'audio_event_import_id' => import.id }
    }
  }

  let!(:tag_crickets) {
    create(:tag, text: 'crickets', type_of_tag: :common_name, is_taxonomic: true)
  }

  describe 'failure cases' do
    it 'fails when given an empty file' do
      parser = Api::AudioEventParser.new(import)
      results = parser.parse('', nil)

      expect(results).to be_an_instance_of(Dry::Monads::Result::Failure)
      expect(results.failure).to eq 'File must not be empty'
    end

    it 'fails when given an unknown format' do
      parser = Api::AudioEventParser.new(import)
      results = parser.parse('fLaC', nil)

      expect(results).to be_an_instance_of(Dry::Monads::Result::Failure)
      expect(results.failure).to eq 'File be a CSV with headers, a Raven file, or a JSON array'
    end
  end

  describe 'importing a website export' do
    let(:baw_format) {
      <<~CSV
        audio_event_id,audio_recording_id,audio_recording_uuid,audio_recording_start_date_australia_brisbane_10_00,audio_recording_start_time_australia_brisbane_10_00,audio_recording_start_datetime_australia_brisbane_10_00,event_created_at_date_australia_brisbane_10_00,event_created_at_time_australia_brisbane_10_00,event_created_at_datetime_australia_brisbane_10_00,projects,site_id,site_name,event_start_date_australia_brisbane_10_00,event_start_time_australia_brisbane_10_00,event_start_datetime_australia_brisbane_10_00,event_start_seconds,event_end_seconds,event_duration_seconds,low_frequency_hertz,high_frequency_hertz,is_reference,created_by,updated_by,common_name_tags,common_name_tag_ids,species_name_tags,species_name_tag_ids,other_tags,other_tag_ids,listen_url,library_url
        259695,#{audio_recording.id},d9e5c6c1-aabf-482c-8f52-83f05531970c,2015-06-01,12:24:16,2015-06-01T12:24:16+10:00,2018-07-01,03:00:23,2018-07-01T03:00:23+10:00,1033:Bristle Whistle,1186,CWS Aviaries (0m) ,2015-06-01,12:41:37,2015-06-01T12:41:37+10:00,1041.6642,1042.9645,1.3003,3143.8477,8397.9492,false,639,639,,,,,,,http://api.ecosounds.org/listen/262864?start=1020&end=1050,http://api.ecosounds.org/library/262864/audio_events/259695
        259314,#{audio_recording.id},d9e5c6c1-aabf-482c-8f52-83f05531970c,2015-06-01,12:24:16,2015-06-01T12:24:16+10:00,2018-06-10,10:51:57,2018-06-10T10:51:57+10:00,1033:Bristle Whistle,1186,CWS Aviaries (0m) ,2015-06-01,12:41:11,2015-06-01T12:41:11+10:00,1015.6348,1018.1658,2.531,1636.5234,7795.0195,true,639,639,63:Crickets|74:Eastern Bristlebird|147:Pied Currawong,63|74|147,,,595:unsure:general|1142:overlap:general,595|1142,http://api.ecosounds.org/listen/262864?start=990&end=1020,http://api.ecosounds.org/library/262864/audio_events/259314

      CSV
    }
    let(:baw_basename) {
      'bristle_whistle_1033_cws_aviaries_0m_1186-20220829-025114.csv'
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import)
      results = parser.parse(baw_format, baw_basename).value!
      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(AudioEvent))

      results => [r1, r2]

      expect(r1).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: nil,
        start_time_seconds: 1041.6642,
        end_time_seconds: 1042.9645,
        low_frequency_hertz: 3143.8477,
        high_frequency_hertz: 8397.9492,
        is_reference: false,
        id: nil
      )

      expect(r1.tags.map(&:as_json)).to match([])

      expect(r2).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: nil,
        start_time_seconds: 1015.6348,
        end_time_seconds: 1018.1658,
        low_frequency_hertz: 1636.5234,
        high_frequency_hertz: 7795.0195,
        is_reference: true,
        id: nil
      )

      expect(r2.tags.map(&:as_json)).to match([
        a_hash_including(
          'text' => tag_crickets.text,
          'id' => tag_crickets.id
        ),
        a_hash_including(
          'text' => 'Eastern Bristlebird',
          'notes' => notes
        ),
        a_hash_including(
          'text' => 'Pied Currawong',
          'notes' => notes
        ),
        a_hash_including(
          'text' => 'unsure',
          'notes' => notes
        ),
        a_hash_including(
          'text' => 'overlap',
          'notes' => notes
        )
      ])
    end
  end

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
      parser = Api::AudioEventParser.new(import)
      results = parser.parse(ap_json, ap_json_basename).value!
      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(AudioEvent))

      results => [r1, r2]

      expect(r1).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: nil,
        start_time_seconds: be_within(0.001).of(47.28743764172336),
        end_time_seconds: be_within(0.001).of(47.72861678004535),
        low_frequency_hertz: 5800.0,
        high_frequency_hertz: 8200.0,
        is_reference: false,
        id: nil
      )

      expect(r1.tags.map(&:as_json)).to match([
        a_hash_including(
          'text' => 'Tyto tenebricosa',
          'notes' => notes
        )
      ])

      expect(r2).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: nil,
        start_time_seconds: be_within(0.001).of(49.43528344671202),
        end_time_seconds: be_within(0.001).of(52.12879818594104),
        low_frequency_hertz: 1200.0,
        high_frequency_hertz: 6500.0,
        is_reference: false,
        id: nil
      )

      expect(r2.tags.map(&:as_json)).to match([
        a_hash_including(
          'text' => 'Tyto tenebricosa',
          'notes' => notes
        )
      ])

      # test object equivalence - we shouldn't be creating duplicate new tags
      expect(r1.tags.first).to eq r2.tags.first
    end
  end

  describe 'Raven files' do
    let(:raven) {
      <<~FILE
        Selection	View	Channel	Begin Time (s)	End Time (s)	Low Freq (Hz)	High Freq (Hz)	Delta Time (s)	Delta Freq (Hz)	Avg Power Density (dB FS/Hz)	Annotation
        1	Waveform 1	1	6.709509878	15.096397225	1739.012	3798.813	8.3869	2059.801		Birb
        1	Spectrogram 1	1	6.709509878	15.096397225	1739.012	3798.813	8.3869	2059.801	-75.87	Birb
        2	Waveform 1	1	29.383026016	40.257059266	1587.060	4136.485	10.8740	2549.426		donkey
        2	Spectrogram 1	1	29.383026016	40.257059266	1587.060	4136.485	10.8740	2549.426	-75.64	donkey
      FILE
    }

    let(:raven_basename) {
      "#{audio_recording.friendly_name}.Table.1.selections.txt"
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import)
      results = parser.parse(raven, raven_basename).value!
      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(AudioEvent))

      results => [r1, r2]

      expect(r1).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: be_within(0.001).of(6.709509878),
        end_time_seconds: be_within(0.001).of(15.096397225),
        low_frequency_hertz: be_within(0.001).of(1739.012),
        high_frequency_hertz: be_within(0.001).of(3798.813),
        is_reference: false,
        id: nil
      )

      expect(r1.tags.map(&:as_json)).to match([
        a_hash_including(
          'text' => 'Birb',
          'notes' => notes
        )
      ])

      expect(r2).to have_attributes(
        audio_event_import_id: import.id,
        audio_recording_id: audio_recording.id,
        channel: 1,
        start_time_seconds: be_within(0.001).of(29.383026016),
        end_time_seconds: be_within(0.001).of(40.257059266),
        low_frequency_hertz: be_within(0.001).of(1587.060),
        high_frequency_hertz: be_within(0.001).of(4136.485),
        is_reference: false,
        id: nil
      )

      expect(r2.tags.map(&:as_json)).to match([
        a_hash_including(
          'text' => 'donkey',
          'notes' => notes
        )
      ])
    end
  end
end
