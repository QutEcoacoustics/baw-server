
# settings loaded in config/initializers/config.rb
# Accessible through Settings.xxx
# Environment specific settings expected in config/settings/{environment_name}.yml
module BawWeb
  module Settings
    MEDIA_PROCESSOR_LOCAL = 'local'
    MEDIA_PROCESSOR_RESQUE = 'resque'

    def sources
      @config_sources.map { |s| s.instance_of?(Config::Sources::YAMLSource) ? s.path : s }
    end

      # Create or return an existing Api::Response.
      # @return [Api::Response]
      def api_response
        @api_response ||= Api::Response.new
      end

      # Create or return an existing RangeRequest.
      # @return [RangeRequest]
      def range_request
        @range_request ||= RangeRequest.new
      end

      def version_info
        {
            major: 2,
            minor: 0,
            patch: 1,
            pre: 0,
            build: ''
        }
      end

      def version_string
        version = "#{version_info[:major]}.#{version_info[:minor]}.#{version_info[:patch]}"

        unless version_info[:pre].blank?
          version += "-#{version_info[:pre]}"
        end

        unless version_info[:build].blank?
          version += "+#{version_info[:build]}"
        end

        version
      end

      # Get the supported media types.
      # @return [Hash]
      def supported_media_types
        if @media_types.blank?
          @media_types = {}

          available_formats.each do |key, value|
            media_category = key.to_sym
            @media_types[media_category] = []

            value.each do |media_type|
              ext = media_type.downcase.trim('.', '')
              mime_type = Mime::Type.lookup_by_extension(ext)
              @media_types[media_category].push mime_type unless mime_type.blank?
            end
            #@media_types[media_category].sort { |a, b| a.to_s <=> b.to_s }
          end
        end

        @media_types
      end

      def is_supported_text_media?(requested_format)
        supported_media_types[:text].include?(requested_format)
      end

      def is_supported_audio_media?(requested_format)
        supported_media_types[:audio].include?(requested_format)
      end

      def is_supported_image_media?(requested_format)
        supported_media_types[:image].include?(requested_format)
      end

      def media_category(requested_format)
        if is_supported_text_media?(requested_format)
          [:text, {}]
        elsif is_supported_audio_media?(requested_format)
          [:audio, cached_audio_defaults]
        elsif is_supported_image_media?(requested_format)
          [:image, cached_spectrogram_defaults]
        else
          [:unknown, {}]
        end
      end

      def process_media_locally?
        media_request_processor == MEDIA_PROCESSOR_LOCAL
      end

      def process_media_resque?
        media_request_processor == MEDIA_PROCESSOR_RESQUE
      end

      def min_duration_larger_overlap?
        audio_recording_max_overlap_sec >= audio_recording_min_duration_sec
      end

  end
end