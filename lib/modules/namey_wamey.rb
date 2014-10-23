class NameyWamey

  # Suggest a file name based on audio recording, start and end offsets, extra options and extension.
  # @param [AudioRecording] audio_recording
  # @param [float] start_offset
  # @param [float] end_offset
  # @param [Hash|string] extra_options
  # @param [string] extension
  # @return [string] suggested file name
  def self.create_audio_recording_name(audio_recording, start_offset, end_offset, extra_options, extension)

    start_offset_float = start_offset.to_f
    end_offset_float = end_offset.to_f
    abs_start = audio_recording.recorded_date.dup.advance(seconds: start_offset_float).strftime('%Y%m%d_%H%M%S')
    duration = end_offset_float - start_offset_float
    site_name = audio_recording.site.name.gsub(' ', '_')
    site_id = audio_recording.site.id.to_s
    extra_options_formatted = self.get_extra_options(extra_options)

    "#{site_name}_#{site_id}_#{audio_recording.id}_#{abs_start}_#{duration}#{extra_options_formatted}.#{extension.trim('.', '')}"
  end

  # Suggest a file name based on project, extra options and extension.
  # @param [Project] project
  # @param [Hash|string] extra_options
  # @param [string] extension
  # @return [string] suggested file name
  def self.create_project_name(project, extra_options, extension)
    extra_options_formatted = self.get_extra_options(extra_options)

    "#{project.name}_#{project.id}#{extra_options_formatted}.#{extension.trim('.', '')}"
  end

  # Suggest a file name based on project, site, extra options and extension.
  # @param [Project] project
  # @param [Site] site
  # @param [Hash|string] extra_options
  # @param [string] extension
  # @return [string] suggested file name
  def self.create_site_name(project, site, extra_options, extension)
    extra_options_formatted = self.get_extra_options(extra_options)
    "#{project.name}_#{project.id}_#{site.name}_#{site.id}#{extra_options_formatted}.#{extension.trim('.', '')}"
  end

  def self.trim(string_value, chars_to_replace, char_to_insert)
    "#{string_value}".gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
  end

  private

  def self.get_extra_options(extra_options)
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