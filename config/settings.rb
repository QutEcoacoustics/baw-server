# frozen_string_literal: true

module BawWeb
  # settings loaded in config/initializers/config.rb
  # Accessible through Settings.xxx
  # Environment specific settings expected in config/settings/{environment_name}.yml
  module Settings
    MEDIA_PROCESSOR_LOCAL = 'local'
    MEDIA_PROCESSOR_RESQUE = 'resque'
    BAW_SERVER_VERSION_KEY = 'BAW_SERVER_VERSION'

    def sources
      @config_sources.map { |script| script.instance_of?(Config::Sources::YAMLSource) ? script.path : script }
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

    # Returns a list of IPs that we allows access to for internal endpoints
    # @return [Array<IPAddr>]
    def internal_allow_ips
      @internal_allow_ips ||= internal.allow_list.map(&IPAddr.method(:new))
    end

    # Tests whether a remote IP falls within any range of our allow list of IPs
    # for internal endpoints
    # @param [String,IPAddr] remote_ip - the IP to test
    # @return [Boolean] true if falls within any allowed range.
    def internal_allow_remote_ip?(remote_ip)
      internal_allow_ips.any? { |ip| ip.include?(remote_ip) }
    end

    def version_info
      return @version_info unless @version_info.nil?

      version = ENV.fetch(BAW_SERVER_VERSION_KEY, nil)
      version = File.read(Rails.root / 'VERSION').strip if version.blank?
      segments = /v?(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g([a-f0-9]+))?/.match(version)
      @version_info = {
        major: segments&.[](1).to_s,
        minor: segments&.[](2).to_s,
        patch: segments&.[](3).to_s,
        pre: segments&.[](4).to_s,
        build: segments&.[](5).to_s
      }
      @version_info
    end

    def version_string
      info = version_info
      version = "#{info[:major]}.#{info[:minor]}.#{info[:patch]}"

      version += "-#{info[:pre]}" if info[:pre].present?

      version += "+#{info[:build]}" if info[:build].present?

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
            @media_types[media_category].push mime_type if mime_type.present?
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

    def supported_audio_event_import_file_media_types
      @supported_audio_event_import_file_media_types ||=
        audio_event_imports
          .acceptable_content_types
          .map { |type| Mime::Type.lookup_by_extension(type) }
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

    def queue_names
      @queue_names ||= resque.queues_to_process
    end

    def queue_to_process_includes?(name)
      queue_names.include?(name) || queue_names.include?('*')
    end

    # Gets the path to the to do harvester directory.
    # @return [Pathname]
    def root_to_do_path
      @root_to_do_path ||= Pathname(actions.harvest.to_do_path).realpath
    end
  end
end

# For go to definition support in IDE
# @!parse
#   class Settings
#     include BawWeb::Settings
#     extend BawWeb::Settings
#   end
