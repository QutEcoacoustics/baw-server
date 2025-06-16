# frozen_string_literal: true

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Parses tags, particularly the baw id:text[:type] format
    class TagTransformer < KeyTransformer
      # an id number followed by a colon and then some text
      BAW_TAG = /\d+:.+/
      LIST_OF_TAGS = /.*;.*/
      def initialize(*keys)
        super(*keys, multi: true)
      end

      # parses values like `63:Crickets|74:Eastern Bristlebird|147:Pied Currawong`
      # or `,595:unsure:general|1142:overlap:general`
      def transform(key, value)
        return None() if value.blank?

        case value
        in BAW_TAG
          transform_baw_format(key, value)
        in LIST_OF_TAGS
          transform_semicolon_list(key, value)
        else
          value
        end => new_value

        # sometimes value is an array, e.g. from a JSON array
        # even if we didn't have to split the string
        new_value = new_value.is_a?(Array) ? new_value.map(&:strip) : new_value.strip

        Some(new_value)
      end

      def transform_baw_format(_key, value)
        value.split('|').map do |tag_and_id|
          tag_and_id.split(':').second
        end
      end

      def transform_semicolon_list(_key, value)
        value.split(';')
      end
    end
  end
end
