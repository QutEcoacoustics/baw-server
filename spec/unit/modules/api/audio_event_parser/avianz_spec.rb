# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'avianz files' do
    #! AviaNZ have had multiple changes to their file format
    # Some of this is detailed here:
    # https://github.com/smarsland/AviaNZ/blob/794343335b81d5fa6a3be299930eab8ba5a139cd/Segment.py#L293-L328
    # We're not going to worry about old formats unless someone complains.

    let(:avianz) {
      # intentionally not pretty printed because the real data is not pretty printed
      <<~JSON
        [{"Operator": "John 117", "Reviewer": "Cortana", "Duration": 3597.9946666666665}, [4.180360677083334, 5.8100286458333334, 503, 3585, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [17.6011796875, 18.1144609375, 924, 3766, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [13.79862109375, 15.590828125, 679, 2320, [{"filter": "M", "species": "Test One", "certainty": 100}]], [24.201462239583332, 28.56863020833333, 802, 3717, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [36.19694140625, 39.57604296875, 508, 3545, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [52.45986588541667, 58.238557291666666, 336, 3668, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [43.01269921875, 43.85961328125, 7489, 9742, [{"filter": "M", "species": "Test Two", "certainty": 100}]], [44.685140625, 46.51584375, 532, 2271, [{"filter": "M", "species": "Test Three", "certainty": 100}]], [50.495311197916664, 51.11552604166667, 7464, 9767, [{"filter": "M", "species": "Test Two", "certainty": 100}]], [51.4255, 52.4520625, 116, 1414, [{"filter": "M", "species": "Test Four", "certainty": 100}]], [56.48912369791667, 57.194885416666665, 7334, 9442, [{"filter": "M", "species": "Test One", "certainty": 100}]], [57.68392708333332, 59.14677864583332, 190, 1088, [{"filter": "M", "species": "Test Five", "certainty": 100}]], [60.365821614583325, 61.11007942708332, 971, 2591, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [0.5090039062500004, 1.2062109375000003, 7398, 9488, [{"filter": "M", "species": "Test One", "certainty": 100}]], [2.12583984375, 2.75033203125, 420, 1191, [{"filter": "M", "species": "Test Five", "certainty": 100}]], [116.38013151041666, 117.11583463541666, 583, 1536, [{"filter": "M", "species": "Test Six", "certainty": 100}]], [115.26471744791667, 116.50086979166667, 1577, 2692, [{"filter": "M", "species": "Test Seven", "certainty": 100}]], [122.01421354166665, 125.61145963541665, 522, 2571, [{"filter": "M", "species": "Australian Raven", "certainty": 100}]], [125.79667447916668, 126.51099088541669, 1536, 2652, [{"filter": "M", "species": "Test Eight", "certainty": 100}]], [157.40682421875002, 158.3350078125, 1374, 2246, [{"filter": "M", "species": "Test Six", "certainty": 100}]], [170.51277604166665, 170.92340104166666, 1759, 2449, [{"filter": "M", "species": "Test Three", "certainty": 100}]], [292.95384765625, 298.42884765625, 2240, 3947, [{"filter": "M", "species": "Test Three", "certainty": 100}]], [294.75888671875, 296.3372265625, 583, 1658, [{"filter": "M", "species": "Test Four", "certainty": 100}]], [341.70607291666664, 346.03902213541664, 785, 3057, [{"filter": "M", "species": "Test Five", "certainty": 100}]], [406.30313932291665, 408.0525729166667, 258, 2104, [{"filter": "M", "species": "Test Eight", "certainty": 100}]], [423.72488541666667, 429.76449479166666, 5208, 9691, [{"filter": "M", "species": "Test Two", "certainty": 100},{"filter": "M", "species": "Test Three", "certainty": 100}]], [425.16635026041666, 430.2007838541667, 1556, 4396, [{"filter": "M", "species": "Rosella (Crimson)", "certainty": 100}, {"filter": "M", "species": "Test 4", "certainty": 50}]]]
      JSON
    }

    let(:avianz_basename) {
      "#{audio_recording.friendly_name}.wav.data"
    }

    let(:results) {
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(avianz, avianz_basename)

      parser.serialize_audio_events
    }

    let(:r1) { results[0] }
    let(:r26_a) { results[25] }
    let(:r26_b) { results[26] }
    let(:r27_a) { results[27] }
    let(:r27_b) { results[28] }

    let(:common) {
      {
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty)
      }
    }

    it 'can parse events' do
      # since avianz can attach different scores or filters to different tags, we have to split them into different events
      # We have 27 events, and 29 results because two of the events have two tags
      expect(results).to have(29).items.and(all(be_an_instance_of(Hash)))

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 4.180360677083334,
        end_time_seconds: 5.8100286458333334,
        low_frequency_hertz: 503,
        high_frequency_hertz: 3585,
        import_file_index: 0,
        score: 100,
        tags: [
          a_hash_including(
            text: 'Australian Raven'
          )
        ]
      ))

      expect(r26_a).to match(a_hash_including(
        **common,
        start_time_seconds: 423.72488541666667,
        end_time_seconds: 429.76449479166666,
        low_frequency_hertz: 5208,
        high_frequency_hertz: 9691,
        import_file_index: 25,
        score: 100,
        tags: [
          a_hash_including(
            text: 'Test Two'
          )
        ]
      ))

      expect(r26_b).to match(a_hash_including(
        **common,
        start_time_seconds: 423.72488541666667,
        end_time_seconds: 429.76449479166666,
        low_frequency_hertz: 5208,
        high_frequency_hertz: 9691,
        import_file_index: 25,
        score: 100,
        tags: [
          a_hash_including(
            text: 'Test Three'
          )
        ]
      ))

      expect(r27_a).to match(a_hash_including(
        **common,
        start_time_seconds: 425.16635026041666,
        end_time_seconds: 430.2007838541667,
        low_frequency_hertz: 1556,
        high_frequency_hertz: 4396,
        import_file_index: 26,
        score: 100,
        tags: [
          a_hash_including(
            text: 'Rosella (Crimson)'
          )
        ]
      ))

      expect(r27_b).to match(a_hash_including(
        **common,
        start_time_seconds: 425.16635026041666,
        end_time_seconds: 430.2007838541667,
        low_frequency_hertz: 1556,
        high_frequency_hertz: 4396,
        import_file_index: 26,
        score: 50,
        tags: [
          a_hash_including(
            text: 'Test 4'
          )
        ]
      ))
    end
  end
end
