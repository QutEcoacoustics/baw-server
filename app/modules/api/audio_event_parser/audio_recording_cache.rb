# frozen_string_literal: true

module Api
  class AudioEventParser
    # A tag resolver and creator that caches input.
    class AudioRecordingCache
      def initialize
        @cache = {}
      end

      def resolve(audio_recording_id)
        return @cache[audio_recording_id] if @cache[audio_recording_id]

        # TODO: handle missing audio recording ids

        result = AudioRecording.find_by(id: audio_recording_id.to_i)
        @cache[audio_recording_id] = result

        result
      end
    end
  end
end
