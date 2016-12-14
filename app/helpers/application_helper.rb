module ApplicationHelper

  def titles(which_title = :title)
    which_title_sym = which_title.to_s.to_sym

    title = content_for?(:title) ? content_for(:title) : nil
    selected_title = content_for?(which_title_sym) ? content_for(which_title_sym) : title

    fail ArgumentError, 'Must provide at least title.' if selected_title.blank?

    selected_title
  end

  def format_sidebar_datetime(value, options = {})
    options.reverse_merge!({ago: true})
    time_distance = distance_of_time_in_words(Time.zone.now, value, nil, {vague: true})
    time_distance = time_distance + ' ago' if options[:ago]
    time_distance
  end

  # https://gist.github.com/suryart/7418454
  def bootstrap_class_for(flash_type)
    flash_types = {success: 'alert-success', error: 'alert-danger', alert: 'alert-warning', notice: 'alert-info'}
    flash_type_keys = flash_types.keys.map { |k| k.to_s }

    flash_type_keys.include?(flash_type.to_s) ? flash_types[flash_type.to_sym] : 'alert-info'
  end

  # make our custom url generation methods available to views
  include Api::CustomUrlHelpers

  def menu_definition
    current_user = controller.current_user
    has_custom_menu = controller.respond_to?(:nav_menu)

    items = controller.global_nav_menu

    # insert custom_items into the stream
    if has_custom_menu
      custom_menu = has_custom_menu ? controller.nav_menu : nil
      custom_items = custom_menu[:menu_items]
      custom_insert_point = custom_menu[:anchor_after]

      insert_index = nil
      insert_index = items.find_index { | menu_item|
          menu_item[:title] == custom_insert_point
      } unless custom_insert_point.nil?

      if insert_index.nil?
        # or add custom items to the end if they didn't find a place
        items = items + [nil] + custom_items
      else
        items = items[0..insert_index] + custom_items + items[insert_index+1..-1]
      end
    end

    # filter items based on their predicate (if it exists)
    items = items.select { |menu_item|
      next true if menu_item.nil?
      next true unless menu_item.include?(:predicate)

      next menu_item[:predicate].call(current_user)
    }

    # finally transform any dynamic hrefs
    items = items.map { |menu_item|
      next menu_item if menu_item.nil?
      next menu_item unless menu_item[:href].respond_to?(:call)

      # clone hash so we don't overwrite values
      new_item = menu_item.dup
      new_item[:href] = menu_item[:href].call(current_user)
      next new_item
    }

    # noinspection RubyUnnecessaryReturnStatement
    return items
  end

end
