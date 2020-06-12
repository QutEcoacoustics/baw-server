# Inspired by https://gist.github.com/remino/8338854
# https://github.com/rails/rails/blob/4-2-8/actionview/lib/action_view/template/handlers/raw.rb
# https://github.com/rails/rails/blob/5-0-stable/actionview/lib/action_view/template/handlers/html.rb
class MarkdownHandler

  def call(template, _source)
    erb = ActionView::Template.registered_template_handler(:erb)

    compiled_template = erb.call(template)

    <<-SOURCE
        CustomRender::render_markdown(begin;#{compiled_template};end).html_safe
    SOURCE
  end
end

ActionView::Template.register_template_handler :md, MarkdownHandler.new
ActionView::Template.register_template_handler :markdown, MarkdownHandler.new