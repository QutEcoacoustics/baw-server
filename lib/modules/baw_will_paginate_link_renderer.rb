require 'cgi'
require 'will_paginate/core_ext'
require 'will_paginate/view_helpers'
require 'will_paginate/view_helpers/link_renderer_base'

class BawWillPaginateLinkRenderer < WillPaginate::ActionView::LinkRenderer
  # # Process it! This method returns the complete HTML string which contains
  # # pagination links. Feel free to subclass LinkRenderer and change this
  # # method as you see fit.
  # def to_html
  #   html = pagination.map do |item|
  #     item.is_a?(Fixnum) ?
  #         page_number(item) :
  #         send(item)
  #   end.join(@options[:link_separator])
  #
  #   @options[:container] ? html_container(html) : html
  # end
  #
  # def page_number(page)
  #   if page == current_page
  #     tag(:li, tag(:span, page), class: 'active')
  #   else
  #     link(page, page, :rel => rel_value(page))
  #   end
  # end
  #
  # def html_container(html)
  #   tag(:div, tag(:ul, html), container_attributes)
  # end
  #
  # def previous_page
  #   num = @collection.current_page > 1 && @collection.current_page - 1
  #   previous_or_next_page(num, '&laquo;', 'previous_page')
  # end
  #
  # def next_page
  #   num = @collection.current_page < total_pages && @collection.current_page + 1
  #   previous_or_next_page(num, '&raquo;', 'next_page')
  # end
  #
  # def previous_or_next_page(page, text, classname)
  #   if page
  #     link(text, page, :class => classname)
  #   else
  #     tag(:li, tag(:a, text), :class => classname + ' disabled')
  #   end
  # end
  #
  # def link(text, target, attributes = {})
  #   if target.is_a? Fixnum
  #     attributes[:rel] = rel_value(target)
  #     target = url(target)
  #   end
  #   attributes[:href] = target
  #   tag(:a, text, attributes)
  # end

end