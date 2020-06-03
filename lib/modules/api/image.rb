# frozen_string_literal: true

module Api
  # Handles extracting image urls
  class Image
    class << self
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
