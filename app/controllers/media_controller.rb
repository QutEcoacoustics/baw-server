class MediaController < ApplicationController
  skip_authorization_check only: [:show]

  def show
    # normalise params and get access to rails request instance
    request_params = CleanParams.perform(params.dup)

    # should the response include content?
    is_head_request = request.head?

    # check authorisation manually, take audio event into account
    audio_recording, audio_event = authorise_custom(request_params, current_user)

    # can the audio recording be accessed?
    is_audio_ready = audio_recording_ready?(audio_recording)

    # parse and validate the requested media type
    requested_format, requested_media_type = get_media_type(request_params)
    is_text = Settings.is_supported_text_media?(requested_format)
    is_audio = Settings.is_supported_audio_media?(requested_format)
    is_image = Settings.is_supported_image_media?(requested_format)
    is_supported_format = is_text || is_audio || is_image

    # do initial checking
    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :accepted
    elsif !is_audio_ready && !is_head_request
      fail CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"
    elsif !is_supported_format && is_head_request
      head :not_acceptable
    elsif !is_supported_format && !is_head_request
      supported_types = Settings.supported_media_types
      msg = "Requested format #{requested_format} (#{requested_media_type}) is not acceptable. " +
          'It must be one of available_formats.'
      fail CustomErrors::NotAcceptableError.new(supported_types), msg
    elsif is_supported_format && is_audio_ready

      category, defaults = Settings.media_category(requested_format)

      media_info = {
          category: category,
          defaults: defaults,
          format: requested_format,
          media_type: requested_media_type
      }

      supported_media_response(audio_recording, audio_event, media_info, request_params)
    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end
  end

  private

  def authorise_custom(request_params, user)

    # Can't do anything if not logged in, not in user or admin role, or not confirmed
    if user.blank? || (!user.has_role?(:user) && !user.has_role?(:admin)) || !user.confirmed?
      fail CanCan::AccessDenied, 'Anonymous users, non-admin and non-users, or unconfirmed users cannot access media.'
    end

    audio_recording = auth_custom_audio_recording(request_params)

    if request_params[:audio_event_id].blank?
      [audio_recording, nil]
    else
      audio_event = auth_custom_audio_event(request_params, audio_recording)
      auth_custom_offsets(request_params, audio_recording, audio_event)
      [audio_recording, audio_event]
    end
  end

  def get_media_type(request_params)
    requested_format = request_params[:format].downcase
    requested_media_type = Mime::Type.lookup_by_extension(requested_format).to_s
    [requested_format, requested_media_type]
  end

  def audio_recording_ready?(audio_recording)
    audio_recording.status == 'ready'
  end

  def supported_media_response(audio_recording, audio_event, media_info, request_params)
    rails_request = request

    # get pre-defined settings
    default_audio = Settings.cached_audio_defaults
    default_spectrogram = Settings.cached_spectrogram_defaults

    # parse request
    metadata = Api::MediaMetadata.new(Settings.media_cache_tool, default_audio, default_spectrogram)

    # validate common request parameters
    metadata.check_request_parameters(audio_recording, request_params)

    # original audio recording info
    original = metadata.audio_recording_details(audio_recording)

    # current request parameters - combination of specified and defaults
    current, modified_params = metadata.current_request_details(audio_recording, media_info, request_params)

    if media_info[:category] == :text
      metadata_response = metadata.api_response(audio_recording, original, current, modified_params)
      json_response(metadata_response, current, rails_request)
    elsif [:audio, :image].include?(media_info[:category])
      media_response(audio_recording, metadata, original, current, media_info)
    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end
  end

  # Send json response.
  # @param [Hash] metadata_response
  # @param [Hash] current
  # @param [ActionDispatch::Request] rails_request
  def json_response(metadata_response, current, rails_request)

    wrapped = api_response.build(:ok, metadata_response)

    json_result = wrapped.to_json
    json_result_size = json_result.size.to_s

    headers['Content-Length'] = json_result_size

    if rails_request.head?
      head_response(:ok, {
          content_length: json_result_size,
          content_type: current[:media_type]
      })
    else
      render json: json_result, content_length: json_result_size
    end
  end

  def media_response(audio_recording, metadata, original, current, media_info)
    rails_request = request

    # get pre-defined settings
    media_cache_tool = Settings.media_cache_tool
    range_request = Settings.range_request

    # validate duration min and max defaults against request parameters
    metadata.check_duration_defaults(audio_recording, current, media_info[:defaults])

    # get parameters for creating/retrieving cache
    generation_request = metadata.generation_request(original, current)

    # start timing request
    time_start = Time.now

    if media_info[:category] == :audio
      # check if audio file exists in cache
      cached_audio_info = media_cache_tool.cached_audio_paths(generation_request)
      media_category = :audio

      existing_files = create_media(media_category, cached_audio_info, generation_request, time_start)
      response_local_audio(audio_recording, generation_request, existing_files, rails_request, range_request)
    elsif media_info[:category] == :image
      # check if spectrogram image file exists in cache
      cached_spectrogram_info = media_cache_tool.cached_spectrogram_paths(generation_request)
      media_category = :spectrogram

      existing_files = create_media(media_category, cached_spectrogram_info, generation_request, time_start)
      response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, range_request)
    end

  end

  def create_media(media_category, files_info, generation_request, time_start)
    # determine where media cutting and/ort spectrogram generation will occur
    is_processed_locally = Settings.process_media_locally?
    is_processed_by_resque = Settings.process_media_resque?
    processor = Settings.media_request_processor

    existing_files = files_info.existing

    if existing_files.blank? && is_processed_locally
      add_header_generated_local
      existing_files = create_media_local(media_category, generation_request)

    elsif  existing_files.blank? && is_processed_by_resque
      add_header_generated_remote
      existing_files = create_media_resque(media_category, files_info, generation_request)

    elsif !existing_files.blank?
      add_header_cache

    end

    time_stop = Time.now

    # check that there is at least one existing file
    existing_files = existing_files.compact # remove nils
    if existing_files.blank?
      msg1 = "Could not create #{media_category}"
      msg2 = "using #{processor}"
      msg3 = "from request #{generation_request}"
      msg4 = "for #{files_info}"
      fail BawAudioTools::Exceptions::AudioToolError, "#{msg1} #{msg2} #{msg3} #{msg4}"
    end

    # add timing headers
    add_header_started(time_start)
    add_header_elapsed(time_stop - time_start)

    existing_files
  end

  # Create a media request locally.
  # @param [Symbol] media_category
  # @param [Object] generation_request
  # @return [String] path to existing file
  def create_media_local(media_category, generation_request)
    BawWorkers::MediaAction.make_media_request(media_category, generation_request)
  end


  # Create a media request using resque.
  # @param [Symbol] media_category
  # @param [Hash] files_info
  # @param [Object] generation_request
  # @return [Array<String>] path to existing file
  def create_media_resque(media_category, files_info, generation_request)
    BawWorkers::MediaAction.enqueue(media_category, generation_request)
    poll_media(files_info.possible, Settings.audio_tools_timeout_sec)
  end

  # this will block the request and wait until the resource is available
  # waits up to wait_max seconds
  # @param [Array<String>] expected_files
  # @param [Number] wait_max
  # @return [Array<String>] existing files
  def poll_media(expected_files, wait_max)
    FirePoll.poll("Took longer than #{wait_max} seconds for resque to fulfil media request.", wait_max) do
      existing_files = []
      expected_files.each do |file|
        existing_files.push(file) if File.exists?(file)
      end
      existing_files = existing_files.compact
      existing_files.blank? ? false : existing_files
    end
  end

  def response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, range_request)

    options = generation_request

    response_extra_info = "#{options[:channel]}_#{options[:sample_rate]}_#{options[:window]}_#{options[:colour]}"
    suggested_file_name = NameyWamey.create_audio_recording_name(audio_recording, options[:start_offset], options[:end_offset], response_extra_info, options[:format])

    existing_file = existing_files.first
    content_length = File.size(existing_file)

    add_header_length(File.size(existing_file))

    if rails_request.head?
      head_response_inline(:ok, {content_length: content_length}, options[:media_type], suggested_file_name)

    else
      info = {
          file_path: existing_file,
          response_suggested_file_name: suggested_file_name,
          file_media_type: options[:media_type],
          response_code: :ok
      }
      response_send_file(info)

    end
  end

  def response_local_audio(audio_recording, generation_request, existing_files, rails_request, range_request)
    # headers[RangeRequest::HTTP_HEADER_ACCEPT_RANGES] = RangeRequest::HTTP_HEADER_ACCEPT_RANGES_BYTES

    download_options = {
        media_type: generation_request[:media_type],
        site_name: audio_recording.site.name,
        site_id: audio_recording.site.id,
        recorded_date: audio_recording.recorded_date,
        recording_duration: audio_recording.duration_seconds,
        recording_id: audio_recording.id,
        ext: generation_request[:format],
        file_path: existing_files.first,
        start_offset: generation_request[:start_offset],
        end_offset: generation_request[:end_offset]
    }

    download_file(download_options, rails_request, range_request)
  end

  # Respond with audio range request.
  # @param [Hash] options
  # @param [ActionDispatch::Request] rails_request
  # @param [RangeRequest] range_request
  def download_file(options, rails_request, range_request)
    #raise ArgumentError, 'File does not exist on disk' if full_path.blank?
    # are HEAD requests supported?
    # more info: http://patshaughnessy.net/2010/10/11/activerecord-with-large-result-sets-part-2-streaming-data
    # http://blog.sparqcode.com/2012/02/04/streaming-data-with-rails-3-1-or-3-2/
    # http://stackoverflow.com/questions/3507594/ruby-on-rails-3-streaming-data-through-rails-to-client
    # ended up using StringIO as a MemoryStream to store part of audio file requested.

    info = range_request.build_response(options, rails_request)

    headers.merge!(info[:response_headers])

    is_head_request = rails_request.head?
    has_content = info[:response_has_content]
    is_range = info[:response_is_range]

    info[:response_has_content] = false if is_head_request

    if has_content && is_range
      buffer = write_to_response_stream(info)
      response_send_data(buffer, info)

    elsif has_content && !is_range
      response_send_file(info)

    elsif !has_content
      head_response_inline(info[:response_code],
                           info[:response_headers],
                           info[:file_media_type],
                           info[:response_suggested_file_name])
    else
      fail CustomErrors::UnprocessableEntityError, 'There was a problem with the request.'

    end

  end

  def write_to_response_stream(info)
    # write audio data from the file to a stringIO
    # use the StringIO in send_data

    buffer = ''
    StringIO.open(buffer, 'w') { |string_io|
      @range_request.write_content_to_output(info, string_io)
    }
    buffer
  end

  # Responds with data in buffer, using metadata from info.
  # @param [String] buffer
  # @param [Hash] info
  def response_send_data(buffer, info)
    send_data buffer, response_binary_metadata(info)
  end

  # Responds with file content in file, using metadata from info.
  # @param [Hash] info
  def response_send_file(info)
    send_file info[:file_path], response_binary_metadata(info)
  end

  def response_binary_metadata(info)
    {
        filename: info[:response_suggested_file_name],
        type: info[:file_media_type],
        content_type: info[:file_media_type],
        disposition: 'inline',
        status: info[:response_code]
    }
  end

  def head_response(response_code, response_headers)
    #headers['Content-Transfer-Encoding'] = 'binary'
    #head :ok, content_length: File.size(full_path.first), content_type: options[:media_type], filename: suggested_file_name

    head response_code, response_headers
  end

  def head_response_inline(response_code, response_headers, content_type, suggested_name)
    # return response code and headers with no content
    head_response response_code, response_headers.merge(
        content_type: content_type,
        content_transfer_encoding: 'binary',
        content_disposition: "inline; filename=\"#{suggested_name}\"",
        filename: suggested_name
    )
  end

  def add_header_length(length)
    headers['Content-Length'] = length.to_s
  end

  def add_header_cache
    headers['X-Media-Response-From'] = 'Cache'
  end

  def add_header_generated_remote
    headers['X-Media-Response-From'] = 'Generated Remotely'
  end

  def add_header_generated_local
    headers['X-Media-Response-From'] = 'Generated Locally'
  end

  def add_header_started(start_datetime)
    headers['X-Media-Response-Start'] = start_datetime.httpdate
  end

  def add_header_elapsed(elapsed_seconds)
    headers['X-Media-Elapsed-Seconds'] = elapsed_seconds.to_s
  end

end