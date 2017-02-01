module ApplicationHelper


  def titles(which_title = :title)
    which_title_sym = which_title.to_s.to_sym

    title = content_for?(:title) ? content_for(:title) : nil
    selected_title = content_for?(which_title_sym) ? content_for(which_title_sym) : title

    fail ArgumentError, 'Must provide at least title.' if selected_title.blank?

    selected_title
  end

  def format_sidebar_datetime(value, options = {})
    return "" if value.nil?

    options.reverse_merge!({ago: true})
    time_distance = distance_of_time_in_words(Time.zone.now, value, {vague: true})
    time_distance = time_distance + ' ago' if options[:ago]
    time_distance
  end

  # https://gist.github.com/suryart/7418454
  def bootstrap_class_for(flash_type)
    flash_types = {success: 'alert-success', error: 'alert-danger', alert: 'alert-warning', notice: 'alert-info'}
    flash_type_keys = flash_types.keys.map { |k| k.to_s }

    flash_type_keys.include?(flash_type.to_s) ? flash_types[flash_type.to_sym] : 'alert-info'
  end

  def nav_item(options)
    render partial: 'shared/nav_item', locals: options
  end

  def destroy_button(href, model_name, icon = 'trash')
    render partial: 'shared/nav_button', locals: {
        href: href,
        title: t('helpers.titles.destroy') + ' ' + t('baw.shared.links.' + model_name + '.title').downcase,
        tooltip: t('helpers.tooltips.destroy', model: model_name),
        icon: icon,
        method: :delete,
        confirm: t('helpers.confirm.destroy', model: model_name)
    }
  end

  def edit_link(href, model_name, icon = 'pencil')
    model_text = t('baw.shared.links.' + model_name + '.title').downcase
    words = model_text.split.size == 1 && model_text.singularize == model_text ? 1 : 2
    render partial: 'shared/nav_item', locals: {
        href: href,
        title: t('helpers.titles.edit', count: words) + ' ' + model_text,
        tooltip: t('helpers.tooltips.edit', model: model_name),
        icon: icon
    }
  end

  def new_link(href, model_name, icon = 'plus')
    render partial: 'shared/nav_item', locals: {
        href: href,
        title: t('helpers.titles.new') + ' ' + t('baw.shared.links.' + model_name + '.title').downcase,
        tooltip: t('helpers.tooltips.new', model: model_name),
        icon: icon
    }
  end

  def listen_link(site)
    play_details = site.get_bookmark_or_recording
    play_link = play_details.blank? ? nil : make_listen_path(play_details[:audio_recording], play_details[:start_offset_seconds])

    return nil if play_link.blank?

    render partial: 'shared/nav_item', locals: {
        href: play_link,
        title: t('baw.shared.links.listen.long_title'),
        tooltip: t('baw.shared.links.listen.description'),
        icon: 'headphones'
    }
  end



end
