class NameyWamey
  class << self
    # Suggest a file name based on audio recording, start and end offsets, extra options and extension.
    # @param [AudioRecording] audio_recording
    # @param [float] start_offset
    # @param [float] end_offset
    # @param [Hash|string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_audio_recording_name(audio_recording, start_offset, end_offset, extra_options, extension)

      start_offset_float = start_offset.to_f
      end_offset_float = end_offset.to_f
      abs_start = audio_recording[:recorded_date].dup.advance(seconds: start_offset_float).strftime('%Y%m%d_%H%M%S')
      duration = end_offset_float - start_offset_float

      if audio_recording.is_a?(Hash)
        site = audio_recording[:site]
      else
        site = audio_recording.site
      end

      if site.is_a?(Hash)
        site_name = site[:name].gsub(' ', '_')
        site_id = site[:id].to_s
      else
        site_name = site.name.gsub(' ', '_')
        site_id = site.id.to_s
      end

      extra_options_formatted = get_extra_options(extra_options)

      "#{site_name}_#{site_id}_#{audio_recording[:id]}_#{abs_start}_#{duration}#{extra_options_formatted}.#{extension.trim('.', '')}".parameterize('_')
    end

    # Suggest a file name based on project, extra options and extension.
    # @param [Project] project
    # @param [Hash|string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_project_name(project, extra_options, extension)
      extra_options_formatted = get_extra_options(extra_options)

      if project.is_a?(Hash)
        id = project[:id]
        name = project[:name]
      else
        id = project.id
        name = project.name
      end

      "#{name}_#{id}#{extra_options_formatted}.#{extension.trim('.', '')}".parameterize('_')
    end

    # Suggest a file name based on project, site, extra options and extension.
    # @param [Project] project
    # @param [Site] site
    # @param [Hash|string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_site_name(project, site, extra_options, extension)
      extra_options_formatted = get_extra_options(extra_options)

      if project.is_a?(Hash)
        project_id = project[:id]
        project_name = project[:name]
      else
        project_id = project.id
        project_name = project.name
      end

      if site.is_a?(Hash)
        site_id = site[:id]
        site_name = site[:name]
      else
        site_id = site.id
        site_name = site.name
      end

      "#{project_name}_#{project_id}_#{site_name}_#{site_id}#{extra_options_formatted}.#{extension.trim('.', '')}".parameterize('_')
    end

    def trim(string_value, chars_to_replace, char_to_insert)
      "#{string_value}".gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
    end

    private

    def get_extra_options(extra_options)
      extra_options_formatted = ''
      if extra_options.is_a?(Hash)
        extra_options.each_pair do |key, value|
          extra_options_formatted = "#{value}" if extra_options_formatted.blank?
          extra_options_formatted = "#{extra_options_formatted}_#{value}" unless extra_options_formatted.blank?
        end
      else
        extra_options_formatted = extra_options
      end
      extra_options_formatted.size > 0 ? '_' + extra_options_formatted : extra_options_formatted
    end
  end
end