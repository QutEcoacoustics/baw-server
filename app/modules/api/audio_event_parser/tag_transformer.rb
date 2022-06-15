# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Parses tags, particularly the baw id:text[:type] format
    class TagTransformer < KeyTransformer
      # an id number followed by a colon and then some text
      BAW_TAG = /\d+:.+/
      def initialize(*keys)
        super(*keys, multi: true)
      end

      # parses values like `63:Crickets|74:Eastern Bristlebird|147:Pied Currawong`
      # or `,595:unsure:general|1142:overlap:general`
      def transform(_key, value)
        return value unless BAW_TAG =~ value

        value.split('|').map do |tag_and_id|
          tag_and_id.split(':').second
        end
      end
    end
  end
end
