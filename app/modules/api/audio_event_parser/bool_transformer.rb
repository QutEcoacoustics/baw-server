# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Ensures some numbers are floats
    class BoolTransformer < KeyTransformer
      def initialize(*keys)
        super(*keys, default: false)
      end

      def transform(_key, value)
        return false if value.nil?

        ::ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
