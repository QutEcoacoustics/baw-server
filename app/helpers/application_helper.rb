module ApplicationHelper

  def titles(which_title = :title)
    which_title_sym = which_title.to_s.to_sym

    title = content_for?(:title) ? content_for(:title) : nil
    selected_title = content_for?(which_title_sym) ? content_for(which_title_sym) : title

    fail ArgumentError, 'Must provide at least title.' if selected_title.blank?

    selected_title
  end

  def format_sidebar_datetime(value, options = {})
    options.reverse_merge!({ ago: true})
    time_distance = distance_of_time_in_words(Time.zone.now, value, nil, {vague: true})
    time_distance = time_distance + ' ago' if options[:ago]
    time_distance
  end

  # https://gist.github.com/suryart/7418454
  def bootstrap_class_for(flash_type)
    flash_types = { success: 'alert-success', error: 'alert-danger', alert: 'alert-warning', notice: 'alert-info'}
    flash_type_keys = flash_types.keys.map { |k| k.to_s}

    flash_type_keys.include?(flash_type.to_s) ? flash_types[flash_type.to_sym] : 'alert-info'
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

  def make_library_tag_search_path(tag_text)
    "/library?reference=all&tagsPartial=#{tag_text}"
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
