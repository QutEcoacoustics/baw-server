# frozen_string_literal: true

module Api
  # Handle model images
  class Image
    class << self
      include Rails.application.routes.url_helpers
      # Extract image urls from an image
      # @param [Object] image Fresh model image parameter (ie. fresh_site.image)
      # @return [Array] Array of image urls and sizes
      def image_urls(image)
        # active storage is the new method for storing attachments
        if image.is_a?(ActiveStorage::Attached)
          # when image is deleted, the association may still be cached.
          # `attached?` should demarcate the situation for us
          return [] unless image.attached?

          return [
            options_for_attached(image, :original),
            options_for_thumbnail(image, :thumb)
          ]
        end
        # otherwise, old (paperclip) defaults
        [
          { size: :extralarge, url: image.url(:span4), width: 300, height: 300 },
          { size: :large, url: image.url(:span3), width: 220, height: 220 },
          { size: :medium, url: image.url(:span2), width: 140, height: 140 },
          { size: :small, url: image.url(:span1), width: 60, height: 60 },
          { size: :tiny, url: image.url(:spanhalf), width: 30, height: 30 }
        ]
      end

      private

      def options_for_attached(image, size)
        {
          size:,
          url: rails_storage_proxy_path(image, only_path: true),
          width: image.metadata['width'],
          height: image.metadata['height']
        }
      end

      def options_for_thumbnail(image, size)
        variant = image.variant(resize_to_fill: BawApp.attachment_thumb_size)
        {
          size:,
          url: rails_storage_proxy_path(variant, only_path: true),
          width: BawApp.attachment_thumb_size.first,
          height: BawApp.attachment_thumb_size.second
        }
      end
    end
  end
end
