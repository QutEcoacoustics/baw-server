# frozen_string_literal: true

# A custom scrubber we use to sanitize html
class CustomScrubber < Rails::Html::PermitScrubber
  def keep_node?(node)
    return false if node.name == 'script'

    super
  end

  def scrub_node(node)
    # the default PermitScrubber strips tags but keeps content.
    # For the script case we want to prune the entire sub-tree (i.e. remove script contents too).
    if node.name == 'script'
      node.remove
      return STOP
    end

    super
  end
end

# A custom scrubber we use to sanitize html for inline text.
class CustomInlineScrubber < CustomScrubber
  def initialize
    super
    self.tags = ['strong', 'em']
  end
end

# Renders markdown ot HTML and sanitizes the result
class CustomRender
  class << self
    # Intended for rendering markdown as partials
    # @param [bool] inline - Renders markdown without HTML block elements and all elements except for strong and em,
    #   suitable for conversion to plainish-text strings.
    # @param [integer] words - truncate input string after a number of words. Only used for inline conversion.
    def render_markdown(value, inline: false, words: nil)
      convert(value, inline, words)
    end

    private

    SANITIZER = Rails::Html::SafeListSanitizer.new

    def scrubber
      @scrubber ||= CustomScrubber.new
    end

    def inline_scrubber
      @inline_scrubber ||= CustomInlineScrubber.new
    end

    KRAMDOWN_OPTIONS = { input: 'GFM', hard_wrap: false }.freeze
    def convert(value, inline, words)
      return nil if value.blank?

      case value
      in ActionView::OutputBuffer
        value.to_str
      in String
        value
      else
        value.to_s
      end => value

      html = Kramdown::Document.new(value, KRAMDOWN_OPTIONS).to_html

      if inline
        sanitized = SANITIZER
          .sanitize(html, scrubber: inline_scrubber)
          .squish
        truncated = words.nil? ? sanitized : sanitized.truncate_words(words)
        # cleanup any unbalanced tags
        Nokogiri::HTML.fragment(truncated).to_html
      else
        SANITIZER.sanitize(html, scrubber: scrubber)
      end
    end
  end
end
