class MediaResponseMetadata

  public

  def initialize(request_params = {}, user)
    @user = user
    @request_params = request_params
    @media_cacher = Settings.media_cache_tool
  end

  def details
    default_audio = Settings.cached_audio_defaults
    default_spectrogram = Settings.cached_spectrogram_defaults
    available_formats = Settings.available_formats
    audio_recording = get_audio_recording

    original = get_audio_recording_details(audio_recording)
    current, modified_params = get_current_request_details(audio_recording, default_audio, default_spectrogram)
    request_type, request_defaults = get_request_type(current, default_audio, default_spectrogram)
    check_request_parameters(original, current, request_defaults)
    available = get_available_request_details(audio_recording, current, modified_params, available_formats)


    details = {recording: original, current: current, available: available}

    if modified_params.size > 0
      details[:options] = get_options(original, default_audio, default_spectrogram, available_formats)
    end

    details
  end

  private

  def get_audio_recording
    AudioRecording.where(id: @request_params[:audio_recording_id]).first
  end

  def get_format
    @request_params[:format]
  end

  def rails_url_helpers
    Rails.application.routes.url_helpers
  end

  def get_audio_recording_details(audio_recording)
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
        duration_seconds: audio_recording.duration_seconds,
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

  def get_current_request_details(audio_recording, default_audio, default_spectrogram)
    modified_params = {}

    start_offset = get_param_value(modified_params, :start_offset, 0)
    end_offset = get_param_value(modified_params, :end_offset, audio_recording.duration_seconds)
    audio_event_id = get_param_value(modified_params, :audio_event_id, nil)
    channel = get_param_value(modified_params, :channel, 0)
    sample_rate = get_param_value(modified_params, :sample_rate, audio_recording.sample_rate_hertz)
    window_size = get_param_value(modified_params, :window_size, default_spectrogram.window)
    window_function = get_param_value(modified_params, :window_function, default_spectrogram.window_function)
    colour = get_param_value(modified_params, :colour, default_spectrogram.colour)
    format = get_format

    current_details = {
        start_offset: start_offset,
        end_offset: end_offset,
        audio_event_id: audio_event_id,
        channel: channel,
        sample_rate: sample_rate,
        window_size: window_size,
        window_function: window_function,
        colour: colour,
        media_type: Mime::Type.lookup_by_extension(format),
        extension: format,
        ppms: (sample_rate / window_size) / 1000
    }

    [current_details, modified_params]
  end

  def get_options(audio_recording, default_audio, default_spectrogram, available_formats)

    sox = @media_cacher.audio.audio_sox

    {
        non_wav_valid_sample_rates: [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000],
        channels: [*0..audio_recording.channels],
        statuses: AudioRecording.AVAILABLE_STATUSES,
        audio: {
            duration_max: default_audio.max_duration_seconds,
            duration_min: default_audio.min_duration_seconds,
            formats: available_formats.audio
        },
        image: {
            spectrogram: {
                duration_max: default_spectrogram.max_duration_seconds,
                duration_min: default_spectrogram.min_duration_seconds,
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

  def get_available_request_details(audio_recording, current, modified_params, available_formats)
    audio_keys = [:start_offset, :end_offset, :audio_event_id, :channel, :sample_rate]
    image_keys = [:start_offset, :end_offset, :audio_event_id, :channel, :sample_rate,
                  :window_size, :window_function, :colour]

    {
        audio: create_available_details(audio_recording, current, modified_params, available_formats.audio, audio_keys),
        image: create_available_details(audio_recording, current, modified_params, available_formats.image, image_keys),
        text: create_available_details(audio_recording, current, modified_params, available_formats.text, image_keys)
    }
  end

  def create_available_details(audio_recording, current, modified_params, formats, relevant_keys)
    result = {}
    formats.each do |format|
      # include all settings in object properties
      result[format] = current.slice(*relevant_keys)
      result[format][:media_type] = Mime::Type.lookup_by_extension(format.to_s)
      result[format][:extension] = format
      # only include modified settings in url
      modified_keys = modified_params.slice(*relevant_keys)
      result[format][:url] = rails_url_helpers.audio_recording_media_url(audio_recording, format: format, modified_keys)
    end
    result
  end

  def get_param_value(modified_params, param_name, default_value)
    if @request_params.include?(param_name)
      param_value = @request_params[param_name]
      modified_params[param_name] = param_value
    else
      param_value = default_value
    end
    param_value
  end

  def get_request_type(current, default_audio, default_spectrogram)
    is_audio = AUDIO_MEDIA_TYPES.include?(current[:media_type])
    is_image = IMAGE_MEDIA_TYPES.include?(current[:media_type])

    if is_audio
      request_type = :audio
      request_defaults = default_audio
    elsif is_image
      request_type = :image
      request_defaults = default_spectrogram
    else
      request_type =:json
      request_defaults = {}
    end

    [request_type, request_defaults]
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
    original_duration = original[:duration_seconds].to_f
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

end