# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Ensures some numbers are floats
    class IntTransformer < KeyTransformer
      def transform(_key, value)
        return None() if value.blank?

        Some.coerce(Integer(value, exception: false))
      end
    end
  end
end
