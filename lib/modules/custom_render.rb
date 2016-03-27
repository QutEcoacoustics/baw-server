class CustomRender
  class << self
    def render_markdown(model, attribute)
      value = model[attribute]
      is_blank = value.blank?
      # I don't know why Rubymine complains about Kramdown not being found...
      is_blank ? nil : ApplicationController.helpers.sanitize(Kramdown::Document.new(value).to_html)
    end
  end
end