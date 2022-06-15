# frozen_string_literal: true

module Api
  class AudioEventParser
    # A tag resolver and creator that caches input.
    class TagCache
      def initialize(import_id)
        @cache = {}
        @import_id = import_id
      end

      def map_tags(tags)
        # TODO: cache tag lookup
        tags.map do |tag_text|
          next @cache[tag_text] if @cache.key?(tag_text)

          tag = find_tag(tag_text) || new_tag(tag_text)

          @cache[tag_text] = tag

          tag
        end
      end

      def find_tag(text)
        Tag.first_with_text(text)
      end

      def new_tag(text)
        Tag.new(
          text:,
          notes: {
            created: {
              message: 'Created via audio event import',
              audio_event_import_id: @import_id
            }
          }
        )
      end
    end
  end
end
