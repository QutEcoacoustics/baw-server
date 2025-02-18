# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Ensures some numbers are floats if they're valid
    class FloatTransformer < KeyTransformer
      def transform(_key, value)
        return None() if value.blank?

        Some.coerce(Float(value, exception: false))
      end
    end
  end
end
