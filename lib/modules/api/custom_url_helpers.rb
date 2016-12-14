module Api
  module CustomUrlHelpers
    def make_listen_path(value = nil, start_offset_sec = nil, end_offset_sec = nil)
      return '/listen' if value.blank?

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


    def make_library_path(ar_value = nil, ae_value = nil)
      return '/library' if ar_value.nil? && ae_value.nil?

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
      elsif value.is_a?(Array) && value.all? { |item| item.is_a?(Site) }
        "#{link}siteIds=" + value.map(&:id).join(',')
      else
        fail ArgumentError, "Must provide project or site, got #{value.class}"
      end
    end


    def make_demo_path()
      '/demo'
    end

    def make_birdwalks_path()
      '/birdwalks'
    end

    def make_audio_analysis_path(value = nil)
      link = '/audio_analysis'

      return link if value.blank?

      if value.is_a?(AnalysisJob)
        "#{link}/#{value.id}"
      else
        fail ArgumentError, "Must provide project or site, got #{value.class}"
      end
    end


    # create annotation download link for a user
    def make_user_annotations_path(user_value)
      user_id = user_value.is_a?(User) ? user_value.id : user_value.to_i
      user_tz = user_value.is_a?(User) && !user_value.rails_tz.blank? ? user_value.rails_tz : 'UTC'
      data_request_path(selected_user_id: user_id, selected_timezone_name: user_tz)
    end

    # create annotations download link for a site
    def make_site_annotations_path(project_value, site_value)
      project_id = project_value.is_a?(Project) ? project_value.id : project_value.to_i
      site_id = site_value.is_a?(Site) ? site_value.id : site_value.to_i
      site_tz = site_value.is_a?(Site) && !site_value.rails_tz.blank? ? site_value.rails_tz : 'UTC'
      data_request_path(selected_project_id: project_id, selected_site_id: site_id, selected_timezone_name: site_tz)
    end
  end
end