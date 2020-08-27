# frozen_string_literal: true

class CustomRender
  class << self
    # Intended for rendering markdown as partials
    # @param [bool] inline - Renders markdown without HTML block elements...
    # suitable for conversion to plainish-text strings.
    def render_markdown(value, inline: false, words: 20)
      convert(value, inline, words)
    end

    private

    KRAMDOWN_OPTIONS = { input: 'GFM', hard_wrap: false }.freeze
    def convert(value, inline, words)
      return nil if value.blank?

      html = Kramdown::Document.new(value, KRAMDOWN_OPTIONS).to_html

      if inline
        sanitized = ApplicationController
                    .helpers
                    .sanitize(html, tags: ['strong', 'em'])
                    .squish
        truncated = sanitized.truncate_words(words)
        # cleanup any unbalanced tags
        Nokogiri::HTML.fragment(truncated).to_html
      else
        ApplicationController.helpers.sanitize(html)
      end
    end
  end
end
