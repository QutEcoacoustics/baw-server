# frozen_string_literal: true

module Api
  # Handle model images
  class Image
    class << self
      # Extract image urls from an image
      # @param [Object] image Fresh model image parameter (ie. fresh_site.image)
      # @return [Array] Array of image urls and sizes
      def image_urls(image)
        [
          { size: :extralarge, url: image.url(:span4), width: 300, height: 300 },
          { size: :large, url: image.url(:span3), width: 220, height: 220 },
          { size: :medium, url: image.url(:span2), width: 140, height: 140 },
          { size: :small, url: image.url(:span1), width: 60, height: 60 },
          { size: :tiny, url: image.url(:spanhalf), width: 30, height: 30 }
        ]
      end
    end
  end
end
