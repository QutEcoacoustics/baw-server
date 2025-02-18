# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  describe 'importing Kaleidoscope csv' do
    include_context 'audio_event_parser'

    # TODO: it's hard to find a normal kaleidoscope csv file. We tend to modify them to make them useful.
    # TODO: This sample is manually constructed and may not be accurate.
    let(:kaleidoscope) {
      <<~CSV
        IN FILE,CHANNEL,OFFSET,DURATION,Fmin,Fmax,MANUAL ID,AUTO-ID,INDIR
        #{audio_recording.friendly_name},0,0,12.3,100,1000,Koala,Female,C:/Users/FakeUser/Documents/in
        #{audio_recording.friendly_name},1,123.456,10,533,7777,Koala,,C:/Users/FakeUser/Documents/in
        #{another_recording.friendly_name},0,7500,60,123.56,11025,Crickets,Orthoptera,C:/Users/FakeUser/Documents/in
      CSV
    }

    let(:kaleidoscope_basename) {
      # TODO: again, guessing
      'cluster.csv'
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(kaleidoscope, kaleidoscope_basename)

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
        #score: nil
      }

      expect(r1).to match(a_hash_including(
        **common,
        start_time_seconds: 0.0,
        end_time_seconds: 12.3,
        low_frequency_hertz: 100.0,
        high_frequency_hertz: 1000.0,
        channel: 0,
        audio_recording_id: audio_recording.id,
        import_file_index: 0
      ))
      expect(r1[:tags].pluck(:text)).to match(a_collection_including('Koala', 'Female'))

      expect(r2).to match(a_hash_including(
        **common,
        start_time_seconds: 123.456,
        end_time_seconds: be_within(0.00001).of(133.456),
        low_frequency_hertz: 533.0,
        high_frequency_hertz: 7777.0,
        channel: 1,
        audio_recording_id: audio_recording.id,
        import_file_index: 1
      ))
      expect(r2[:tags].pluck(:text)).to match(a_collection_including('Koala'))

      expect(r3).to match(a_hash_including(
        **common,
        start_time_seconds: 7500,
        end_time_seconds: 7560,
        low_frequency_hertz: 123.56,
        high_frequency_hertz: 11_025.0,
        channel: 0,
        audio_recording_id: another_recording.id,
        import_file_index: 2
      ))
      expect(r3[:tags].pluck(:text)).to match(a_collection_including('crickets', 'Orthoptera'))
    end
  end
end
