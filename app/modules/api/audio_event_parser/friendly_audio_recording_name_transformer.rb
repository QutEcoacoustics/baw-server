# frozen_string_literal: true

module Api
  class AudioEventParser
    # Can parse the audio recording ID from a friendly audio recording name
    class FriendlyAudioRecordingNameTransformer < KeyTransformer
      # Can recognize our friendly audio recording name format from a column
      # and transform it into an audio recording ID
      def transform(_key, value)
        match = AudioRecording::FRIENDLY_NAME_REGEX.match(value)

        return None() if match.nil?

        Some.coerce(match[:id].to_i_strict)
      end
    end
  end
end
