class CustomRender
  class << self

    # @param [bool] inline - Renders markdown without HTML block elements...
    # suitable for conversion to plainish-text strings.
    def render_model_markdown(model, attribute, inline = false)
      value = model[attribute]
      convert(value, inline)
    end

    # Intended for rendering markdown as partials
    def render_markdown(value)
      convert(value, false)
    end

    private

    def convert(value, inline)
      return nil if value.blank?

      # I don't know why Rubymine complains about Kramdown not being found...
      html = Kramdown::Document.new(
          value,
          {input: 'GFM', hard_wrap: false}
      ).to_html

      if inline
        ApplicationController.helpers.sanitize(html, tags: ['strong', 'em'])
      else
        ApplicationController.helpers.sanitize(html)
      end
    end
  end
end