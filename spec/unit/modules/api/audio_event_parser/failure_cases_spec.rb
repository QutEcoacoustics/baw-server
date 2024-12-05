# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'failure cases' do
    it 'fails when given an empty file' do
      parser = Api::AudioEventParser.new(import_file, reader_user)

      parser.parse('', nil) => result

      expect(result).to be_failure.and(have_attributes(failure: 'File must not be empty'))
    end

    it 'fails when given an unknown format' do
      parser = Api::AudioEventParser.new(import_file, reader_user)

      parser.parse('fLaC', nil) => result

      expect(result).to be_failure.and(have_attributes(failure: 'File must be a CSV/TSV with headers, a Raven file, or a JSON array'))
    end

    it 'fails when audio recording is not found' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      file = <<~CSV
        filename,start_offset_seconds,end_offset_seconds,label,score,audio_recording_id
        tests/files/audio/100sec.wav,20.0,25.0,negative,12.739699,999999
      CSV

      result = parser.parse(file, 'abc.csv')

      expect(result).to be_failure.and(have_attributes(failure: 'Validation failed'))

      events = parser.serialize_audio_events

      expect(events.first).to match(a_hash_including(
        errors: [
          {
            audio_recording_id: ['does not exist']

          }
        ]
      ))
    end

    it 'fails when user does not have permission to write to audio recording' do
      parser = Api::AudioEventParser.new(import_file, reader_user)
      file = <<~CSV
        filename,start_offset_seconds,end_offset_seconds,label,score,audio_recording_id
        tests/files/audio/100sec.wav,20.0,25.0,negative,12.739699,#{audio_recording.id}
      CSV

      result = parser.parse(file, 'abc.csv')

      expect(result).to be_failure.and(have_attributes(failure: 'Validation failed'))

      events = parser.serialize_audio_events

      expect(events.first).to match(a_hash_including(
        errors: [
          {
            audio_recording_id: ['you do not have permission to add audio events to this recording']

          }
        ]
      ))
    end
  end
end
