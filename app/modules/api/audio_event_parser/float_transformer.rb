# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Ensures some numbers are floats
    class FloatTransformer < KeyTransformer
      def transform(_key, value)
        value.to_f
      end
    end
  end
end
