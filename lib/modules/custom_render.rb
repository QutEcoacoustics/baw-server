class CustomRender
  class << self
    def render_markdown(model, attribute)
      value = model[attribute]
      is_blank = value.blank?
      is_blank ? nil : ApplicationController.helpers.sanitize(Kramdown::Document.new(value).to_html)
    end
  end
end