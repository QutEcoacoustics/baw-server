class MediaResponseMetadata

  public

  OFFSET_REGEXP = /^\d+(\.\d{1,3})?$/ # passes '111', '11.123'

  def initialize(media_cache_tool, default_audio, default_spectrogram)
    @media_cache_tool = media_cache_tool
    @default_audio = default_audio
    @default_spectrogram = default_spectrogram
  end

  def audio_recording_details(audio_recording)
    if audio_recording.original_file_name.blank?
      stored_media_type = audio_recording.media_type
      stored_extension = Mime::Type.lookup(audio_recording.media_type).to_sym.to_s
    else
      stored_extension = File.extname(audio_recording.original_file_name)
      stored_media_type = Mime::Type.lookup_by_extension(NameyWamey.trim(stored_extension, '.', ''))
    end

    {
        id: audio_recording.id,
        uuid: audio_recording.uuid,
        recorded_date: audio_recording.recorded_date,
        site_id: audio_recording.site_id,
        site_name: audio_recording.site.name,
        duration_seconds: audio_recording.duration_seconds.to_f,
        sample_rate_hertz: audio_recording.sample_rate_hertz,
        channel_count: audio_recording.channels,
        bit_rate_bps: audio_recording.bit_rate_bps,
        media_type: stored_media_type,
        extension: stored_extension,
        data_length_bytes: audio_recording.data_length_bytes,
        file_hash: audio_recording.file_hash,
        status: audio_recording.status,
        uploaded_date: audio_recording.created_at
    }
  end

  def current_request_details(audio_recording, media_info, request_params)
    modified_params = {}

    start_offset = get_param_value(request_params, modified_params, :start_offset, 0)
    end_offset = get_param_value(request_params, modified_params, :end_offset, audio_recording.duration_seconds)
    audio_event_id = get_param_value(request_params, modified_params, :audio_event_id, nil)
    channel = get_param_value(request_params, modified_params, :channel, 0)
    sample_rate = get_param_value(request_params, modified_params, :sample_rate, audio_recording.sample_rate_hertz)
    window_size = get_param_value(request_params, modified_params, :window_size, @default_spectrogram.window)
    window_function = get_param_value(request_params, modified_params, :window_function, @default_spectrogram.window_function)
    colour = get_param_value(request_params, modified_params, :colour, @default_spectrogram.colour)

    current_details = {
        start_offset: start_offset.to_f,
        end_offset: end_offset.to_f,
        audio_event_id: audio_event_id,
        channel: channel,
        sample_rate: sample_rate,
        window_size: window_size,
        window_function: window_function,
        colour: colour,
        media_type: media_info[:media_type],
        extension: media_info[:format],
        ppms: (sample_rate.to_f / window_size.to_f) / 1000.0
    }

    [current_details, modified_params]
  end

  def valid_options(audio_recording, available_formats)

    sox = @media_cache_tool.audio.audio_sox

    {
        # all formats, even wav, must adhere to this list
        valid_sample_rates: [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000],
        channels: [*0..audio_recording.channels],
        #statuses: AudioRecording::AVAILABLE_STATUSES,
        audio: {
            duration_max: @default_audio.max_duration_seconds,
            duration_min: @default_audio.min_duration_seconds,
            formats: available_formats.audio
        },
        image: {
            spectrogram: {
                duration_max: @default_spectrogram.max_duration_seconds,
                duration_min: @default_spectrogram.min_duration_seconds,
                formats: available_formats.image,
                window_sizes: sox.window_options,
                window_functions: sox.window_function_options,
                colours: sox.colour_options,
            }
        },
        text: {
            formats: available_formats.text
        }
    }
  end

  def available_request_details(audio_recording, current, modified_params, available_formats)
    audio_keys = [] #[:start_offset, :end_offset, :audio_event_id, :channel, :sample_rate]
    image_keys = #[:start_offset, :end_offset, :audio_event_id, :channel, :sample_rate,
                  [:window_size, :window_function, :colour, :ppms]
    text_keys = []

    {
        audio: create_available_details(audio_recording, current, modified_params, available_formats.audio, audio_keys),
        image: create_available_details(audio_recording, current, modified_params, available_formats.image, image_keys),
        text: create_available_details(audio_recording, current, modified_params, available_formats.text, text_keys)
    }
  end

  def generation_request(audio_recording_info, current_request_info)
    {
        uuid: audio_recording_info[:uuid],
        format: current_request_info[:extension],
        media_type: current_request_info[:media_type],
        start_offset: current_request_info[:start_offset],
        end_offset: current_request_info[:end_offset],
        channel: current_request_info[:channel],
        sample_rate: current_request_info[:sample_rate],
        datetime_with_offset: audio_recording_info[:recorded_date],
        original_format: audio_recording_info[:extension],
        window: current_request_info[:window_size],
        window_function: current_request_info[:window_function],
        colour: current_request_info[:colour]
    }
  end

  # Create a Hash compatible with the expected API Response.
  # @param [AudioRecording] audio_recording
  # @param [Hash] original
  # @param [Hash] current
  # @param [Hash] modified_params
  def api_response(audio_recording, original, current, modified_params)
    available_formats = Settings.available_formats

    available = available_request_details(audio_recording, current, modified_params, available_formats)

    details = {recording: original, common_parameters: current, available: available}

    if modified_params.size < 1
      valid_options = valid_options(audio_recording, available_formats)
      details[:options] = valid_options
    end

    # ensure media_type for original is a string
    details[:recording][:media_type] = details[:recording][:media_type].to_s

    # keep only required entries
    details[:recording].slice!(
        :id, :uuid, :recorded_date, :duration_seconds, :sample_rate_hertz,
        :channel_count, :media_type
    )

    details[:common_parameters].slice!(
        :start_offset, :end_offset, :audio_event_id, :channel, :sample_rate
    )

    details
  end

  # Check request parameters.
  # @param [Hash] original
  # @param [Hash] current
  # @param [Hash] request_defaults
  def check_request_parameters(original, current, request_defaults)
    # check start and end offset formatting first
    start_offset_s = current[:start_offset].to_s
    end_offset_s = current[:end_offset].to_s

    unless start_offset_s=~OFFSET_REGEXP
      msg = "start_offset parameter (#{start_offset_s}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"
      fail CustomErrors::UnprocessableEntityError, msg
    end

    unless end_offset_s=~OFFSET_REGEXP
      msg = "end_offset parameter (#{end_offset_s}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"

      fail CustomErrors::UnprocessableEntityError, msg
    end

    start_offset = start_offset_s.to_f
    end_offset = end_offset_s.to_f
    requested_duration = end_offset - start_offset
    original_duration = original[:duration_seconds]
    max_duration = request_defaults.max_duration_seconds.to_f
    min_duration = request_defaults.min_duration_seconds.to_f

    # now check bounds
    if requested_duration > max_duration
      msg = "Requested duration #{requested_duration} (#{start_offset} to #{end_offset}) is greater than maximum (#{max_duration})."
      fail BawAudioTools::Exceptions::SegmentRequestTooLong, msg
    end

    if requested_duration < min_duration
      msg = "Requested duration #{requested_duration} (#{start_offset} to #{end_offset}) is less than minimum (#{min_duration})."
      fail BawAudioTools::Exceptions::SegmentRequestTooLong, msg
    end

    if end_offset > original_duration
      msg = "end_offset parameter (#{end_offset}) must be smaller than or equal to the duration of the audio recording (#{original_duration})."
      fail CustomErrors::UnprocessableEntityError, msg
    end

    if end_offset <= 0
      msg = "end_offset parameter (#{end_offset}) must be greater than 0."
      fail CustomErrors::UnprocessableEntityError, msg
    end

    if start_offset >= original_duration
      msg = "start_offset parameter (#{start_offset}) must be smaller than the duration of the audio recording (#{original_duration})."
      fail CustomErrors::UnprocessableEntityError, msg
    end

    if start_offset < 0
      msg = "start_offset parameter (#{start_offset}) must be greater than or equal to 0."
      fail CustomErrors::UnprocessableEntityError, msg
    end

    if start_offset >= end_offset
      msg = "start_offset parameter (#{start_offset}) must be smaller than end_offset (#{end_offset})."
      fail CustomErrors::UnprocessableEntityError, msg
    end
  end

  private

  def rails_url_helpers
    Rails.application.routes.url_helpers
  end

  # Create a Hash representing the available formats for the current request.
  # @param [AudioRecording] audio_recording
  # @param [Hash] current
  # @param [Hash] modified_params
  # @param [Array<String>] formats
  # @param [Hash] relevant_keys
  def create_available_details(audio_recording, current, modified_params, formats, relevant_keys)
    result = {}
    formats.each do |format|
      # include all settings in object properties
      result[format] = current.slice(*relevant_keys)
      result[format][:media_type] = Mime::Type.lookup_by_extension(format.to_s.downcase).to_s
      result[format][:extension] = format
      # only include modified settings in url
      modified_keys = modified_params.merge(format: format)
      result[format][:url] = rails_url_helpers.audio_recording_media_path(audio_recording, modified_keys)
    end
    result
  end

  # Get param value if available, otherwise a default value.
  # @param [ActiveSupport::HashWithIndifferentAccess] request_params
  # @param [Hash] modified_params
  # @param [String] param_name
  # @param [Object] default_value
  def get_param_value(request_params, modified_params, param_name, default_value)
    if request_params.include?(param_name)
      param_value = request_params[param_name]
      modified_params[param_name] = param_value
    else
      param_value = default_value
    end
    param_value
  end

end