module ApplicationHelper

  def sidebar_metadata(title, text)
    unless title.blank? || text.blank?
      content_tag(:div, class: 'metadata') do
        content_tag(:div, title, class: 'heading') +
            content_tag(:div, text, class: 'text')
      end
    end
  end

  def sidebar_metadata_users(title, users)
    unless title.blank? || users[0][:user].blank?
      content_tag(:div, class: 'metadata') do
        content_tag(:div, title, class: 'heading') +
            content_tag(:ul, class: 'thumbnails') do
              users.collect! { |user| render partial: 'user_accounts/user_thumbnail_small', locals: {user: user[:user], subtext: user[:subtext]} }.join.html_safe
            end
      end
    end
  end

  def gmaps_default_options
    {zoom: 7, auto_zoom: false}
  end

  # https://gist.github.com/suryart/7418454
  def bootstrap_class_for flash_type
    flash_types = { success: "alert-success", error: "alert-danger", alert: "alert-warning", notice: "alert-info" }
    flash_type_keys = flash_types.keys.map { |k| k.to_s}

    flash_type_keys.include?(flash_type.to_s) ? flash_types[flash_type.to_sym] : flash_type.to_s
  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, message, class: "alert #{bootstrap_class_for(msg_type)} fade in") do
               concat content_tag(:button, 'x', class: 'close', data: { dismiss: 'alert' })
               concat message
             end)
    end
    nil
  end

  # for constructing links to the angular site
  def make_listen_path(value, start_offset_sec = nil, end_offset_sec = nil)
    fail ArgumentError, 'Must specify a value for make_listen_path.' if value.blank?

    # obtain audio recording id
    if value.is_a?(AudioRecording)
      ar_id = value.id
    elsif value.is_a?(AudioEvent)
      ar_id = value.audio_recording_id
    elsif value.is_a?(Bookmark)
      ar_id = value.audio_recording_id
    else
      ar_id = value.to_i
    end

    # obtain offsets
    if value.is_a?(AudioEvent)
      start_offset_sec = value.start_time_seconds if start_offset_sec.blank?
      end_offset_sec = value.end_time_seconds if end_offset_sec.blank?
    elsif value.is_a?(Bookmark)
      start_offset_sec = value.offset_seconds if start_offset_sec.blank?
    end

    start_offset_sec = end_offset_sec if start_offset_sec.blank? && !end_offset_sec.blank?
    end_offset_sec = start_offset_sec if end_offset_sec.blank? && !start_offset_sec.blank?

    link = "/listen/#{ar_id}"

    if start_offset_sec.blank? && end_offset_sec.blank?
      link
    else
      segment_duration_seconds = 30

      offset_start_rounded = (start_offset_sec / segment_duration_seconds).floor * segment_duration_seconds
      offset_end_rounded = (end_offset_sec / segment_duration_seconds).floor * segment_duration_seconds
      offset_end_rounded += (offset_start_rounded == offset_end_rounded ? segment_duration_seconds : 0)

      "#{link}?start=#{offset_start_rounded}&end=#{offset_end_rounded}"
    end

  end

  def make_library_path(ar_value, ae_value = nil)
    fail ArgumentError, 'Must provide audio recording id.' if ar_value.blank?

    ar_id, ae_id = nil

    # obtain audio recording id
    if ar_value.is_a?(AudioRecording)
      ar_id = ar_value.id
    elsif ar_value.is_a?(AudioEvent)
      ar_id = ar_value.audio_recording_id
      ae_id = ar_value.id
    else
      ar_id = ar_value.to_i
    end

    # obtain audio event id
    if ae_value.is_a?(AudioEvent)
      ae_id = ae_value.id
    elsif !ae_value.blank?
      ae_id = ae_value.to_i
    end

    fail ArgumentError, 'Must provide audio event id' if ae_id.blank?

    "/library/#{ar_id}/audio_events/#{ae_id}"
  end

  def make_visualise_path(value)
    fail ArgumentError, 'Must provide project or site' if value.blank?

    link = '/visualize?'

    if value.is_a?(Project)
      "#{link}projectId=#{value.id}"
    elsif value.is_a?(Site)
      "#{link}siteId=#{value.id}"
    else
      fail ArgumentError, "Must provide project or site, got #{value.class}"
    end
  end

end
