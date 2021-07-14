# frozen_string_literal: true

class NameyWamey
  class << self
    # Suggest a file name based on audio recording, start and end offsets, extra options and extension.
    # @param [AudioRecording] audio_recording
    # @param [float] start_offset
    # @param [float] end_offset
    # @param [Hash,string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_audio_recording_name(audio_recording, start_offset, end_offset, extra_options = '', extension = '')
      start_offset_float = start_offset.to_f
      end_offset_float = end_offset.to_f
      abs_start = audio_recording[:recorded_date].dup.advance(seconds: start_offset_float).strftime('%Y%m%d_%H%M%S')
      duration = end_offset_float - start_offset_float

      site = if audio_recording.is_a?(Hash)
               audio_recording[:site]
             else
               audio_recording.site
             end

      if site.is_a?(Hash)
        site_name = site[:name].gsub(' ', '_')
        site_id = site[:id].to_s
      else
        site_name = site.name.gsub(' ', '_')
        site_id = site.id.to_s
      end

      build_name([site_name, site_id, audio_recording[:id], abs_start, duration], extra_options, extension)
    end

    # Suggest a file name based on project, extra options and extension.
    # @param [Project] project
    # @param [Hash,string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_project_name(project, extra_options = '', extension = '')
      if project.is_a?(Hash)
        id = project[:id]
        name = project[:name]
      else
        id = project.id
        name = project.name
      end

      build_name([name, id], extra_options, extension)
    end

    # Suggest a file name based on project, site, extra options and extension.
    # @param [Project] project
    # @param [Site] site
    # @param [Hash,string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_site_name(project, site, extra_options = '', extension = '')
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

      build_name([project_name, project_id, site_name, site_id], extra_options, extension)
    end

    # Suggest a file name based on user, extra options and extension.
    # @param [User] user
    # @param [Hash,string] extra_options
    # @param [string] extension
    # @return [string] suggested file name
    def create_user_name(user, extra_options = '', extension = '')
      if user.is_a?(Hash)
        user_id = user[:id]
        user_name = user[:name]
      else
        user_id = user.id
        user_name = user.user_name
      end

      build_name([user_name, user_id], extra_options, extension)
    end

    def trim(string_value, chars_to_replace, char_to_insert)
      string_value.to_s.gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
    end

    private

    def get_extra_options(extra_options)
      extra_options_formatted = ''
      case extra_options
      when Hash
        extra_options.each_pair do |_key, value|
          extra_options_formatted = value.to_s if extra_options_formatted.blank?
          extra_options_formatted = "#{extra_options_formatted}_#{value}" unless extra_options_formatted.blank?
        end
      when Array
        extra_options.each do |value|
          extra_options_formatted = value.to_s if extra_options_formatted.blank?
          extra_options_formatted = "#{extra_options_formatted}_#{value}" unless extra_options_formatted.blank?
        end
      else
        extra_options_formatted = extra_options
      end
      extra_options_formatted.empty? ? extra_options_formatted : "_#{extra_options_formatted}"
    end

    def build_name(standard, extra, extension)
      name = standard.join('_') + get_extra_options(extra)
      name_parameterize = name.parameterize(separator: '_')

      "#{name_parameterize}.#{extension.trim('.', '').parameterize(separator: '_')}"
    end
  end
end
