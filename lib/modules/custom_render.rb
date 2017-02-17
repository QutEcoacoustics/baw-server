class CustomRender
  class << self
    def render_model_markdown(model, attribute)
      value = model[attribute]
      render_markdown(value)
    end

    def render_markdown(value)
      return nil if value.blank?

      # I don't know why Rubymine complains about Kramdown not being found...
      html =  Kramdown::Document.new(
          value,
          {input: 'GFM', hard_wrap: false}
      ).to_html

      ApplicationController.helpers.sanitize(html)
    end
  end
end