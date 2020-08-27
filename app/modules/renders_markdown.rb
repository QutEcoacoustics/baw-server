# frozen_string_literal: true

# Standardizes rendering markdown in models
module RendersMarkdown
  extend ActiveSupport::Concern

  class_methods do
    # Adds the convenience methods #{attr}_html for the given attributes.
    # These methods convert a markdown body to sanitized HTML.
    # @!parse
    def renders_markdown_for(*attrs)
      attrs.each do |attr|
        define_method("#{attr}_html".to_sym) do
          render_markdown_for(attr, inline: false)
        end
      end
    end
  end

  # Renders markdown for a given attribute
  def render_markdown_for(attr, inline: false)
    CustomRender.render_markdown(read_attribute(attr), inline: inline)
  end

  def render_markdown_tagline_for(attr, words: 20)
    CustomRender.render_markdown(read_attribute(attr), inline: true, words: words)
  end

  # @returns Hash of values to be merged into the custom fields property of filter_settings
  def render_markdown_for_api_for(attr, words: 20)
    {
      "#{attr}_html".to_sym => render_markdown_for(attr),
      "#{attr}_html_tagline".to_sym => render_markdown_tagline_for(attr, words: words)
    }
  end
end
