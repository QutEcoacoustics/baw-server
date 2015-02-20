class MediaController < ApplicationController
  skip_authorization_check only: [:show]

  def show
    # start timing request
    overall_start = Time.now

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
          media_type: requested_media_type,
          timing_overall_start: overall_start
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
    metadata = Api::MediaMetadata.new(BawWorkers::Config.audio_helper, default_audio, default_spectrogram)

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

    wrapped = Settings.api_response.build(:ok, metadata_response)

    json_result = wrapped.to_json
    json_result_size = json_result.size.to_s

    add_header_length(json_result_size)

    if rails_request.head?
      head_response(
          :ok,
          {
              content_length: json_result_size,
              content_type: current[:media_type]
          })
    else
      render json: json_result, content_length: json_result_size
    end
  end

  def media_response(audio_recording, metadata, original, current, media_info)
    rails_request = request

    # start timing request
    time_start = media_info[:timing_overall_start]
    add_header_started(time_start)

    # get pre-defined settings
    audio_cached = BawWorkers::Config.audio_cache_helper
    spectrogram_cached = BawWorkers::Config.spectrogram_cache_helper
    range_request = Settings.range_request

    # validate duration min and max defaults against request parameters
    metadata.check_duration_defaults(audio_recording, current, media_info[:defaults])

    # get parameters for creating/retrieving cache
    generation_request = metadata.generation_request(original, current)

    if media_info[:category] == :audio
      # check if audio file exists in cache
      cached_audio_info = audio_cached.path_info(generation_request)
      media_category = :audio

      existing_files, time_waiting_start = create_media(media_category, cached_audio_info, generation_request)
      response_local_audio(audio_recording, generation_request, existing_files, rails_request, range_request, time_start, time_waiting_start)
    elsif media_info[:category] == :image
      # check if spectrogram image file exists in cache
      cached_spectrogram_info = spectrogram_cached.path_info(generation_request)
      media_category = :spectrogram

      existing_files, time_waiting_start = create_media(media_category, cached_spectrogram_info, generation_request)
      response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, range_request, time_start, time_waiting_start)
    end

  end

  def create_media(media_category, files_info, generation_request)
    # determine where media cutting and/ort spectrogram generation will occur
    is_processed_locally = Settings.process_media_locally?
    is_processed_by_resque = Settings.process_media_resque?
    processor = Settings.media_request_processor

    existing_files = files_info[:existing]

    time_start_waiting = nil

    if existing_files.blank? && is_processed_locally
      add_header_generated_local
      existing_files = create_media_local(media_category, generation_request)

    elsif  existing_files.blank? && is_processed_by_resque
      add_header_generated_remote
      job_status = create_media_resque(media_category, generation_request)

      time_start_waiting = Time.now

      expected_files = files_info[:possible]
      Rails.logger.info "Expected files in media_controller#create_media: #{expected_files}"

      poll_locations = MediaPoll.prepare_locations(expected_files)
      Rails.logger.info "Filtered expected files in media_controller#create_media: #{poll_locations}"

      # now check if files exists - check fs, do ls, check fs
      # CAUTION: ls can cause high CPU usage

      # first fs check
      existing_files = MediaPoll.check_files(poll_locations)

      if existing_files.blank?
        # just to be sure, do an ls and another check before failing.
        existing_files = MediaPoll.refresh_files(poll_locations)
      end

    elsif !existing_files.blank?
      add_header_cache
      add_header_processing_elapsed(0)
    end

    # check that there is at least one existing file
    existing_files = existing_files.compact # remove nils
    if existing_files.blank?
      msg1 = "Could not create #{media_category}"
      msg2 = "using #{processor}"
      msg3 = "from request #{generation_request}"
      fail BawAudioTools::Exceptions::AudioToolError, "#{msg1} #{msg2} #{msg3}"
    end

    time_start_waiting = Time.now if time_start_waiting.nil?
    [existing_files, time_start_waiting]
  end

  # Create a media request locally.
  # @param [Symbol] media_category
  # @param [Object] generation_request
  # @return [String] path to existing file
  def create_media_local(media_category, generation_request)

    start_time = Time.now
    target_existing_paths = BawWorkers::Media::Action.make_media_request(media_category, generation_request)
    end_time = Time.now

    add_header_processing_elapsed(end_time - start_time)

    target_existing_paths
  end


  # Create a media request using resque.
  # @param [Symbol] media_category
  # @param [Object] generation_request
  # @return [Resque::Plugins::Status::Hash] job status
  def create_media_resque(media_category, generation_request)

    start_time = Time.now
    BawWorkers::Media::Action.action_enqueue(media_category, generation_request)
    #existing_files = MediaPoll.poll_media(expected_files, Settings.audio_tools_timeout_sec)
    job_status = MediaPoll.poll_resque(media_category, generation_request, Settings.audio_tools_timeout_sec)
    end_time = Time.now

    add_header_processing_elapsed(end_time - start_time)

    job_status
  end

  def response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, range_request, time_start, time_waiting_start)

    options = generation_request

    response_extra_info = "#{options[:channel]}_#{options[:sample_rate]}_#{options[:window]}_#{options[:colour]}"
    suggested_file_name = NameyWamey.create_audio_recording_name(audio_recording, options[:start_offset], options[:end_offset], response_extra_info, options[:format])

    existing_file = existing_files.first
    content_length = File.size(existing_file)

    add_header_length(content_length)

    # add overall time taken and waiting time elapsed header
    time_stop = Time.now
    add_header_total_elapsed(time_stop - time_start)
    add_header_waiting_elapsed(time_stop - time_waiting_start)

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

  def response_local_audio(audio_recording, generation_request, existing_files, rails_request, range_request, time_start, time_waiting_start)
    # headers[RangeRequest::HTTP_HEADER_ACCEPT_RANGES] = RangeRequest::HTTP_HEADER_ACCEPT_RANGES_BYTES
    # content length is added by RangeRequest

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

    download_file(download_options, rails_request, range_request, time_start, time_waiting_start)
  end

  # Respond with audio range request.
  # @param [Hash] options
  # @param [ActionDispatch::Request] rails_request
  # @param [RangeRequest] range_request
  def download_file(options, rails_request, range_request, time_start, time_waiting_start)
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

    # add overall time taken header
    time_stop = Time.now
    add_header_total_elapsed(time_stop - time_start)
    add_header_waiting_elapsed(time_stop - time_waiting_start)

    if has_content && is_range
      buffer = write_to_response_stream(info, range_request)
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

  def write_to_response_stream(info, range_request)
    # write audio data from the file to a stringIO
    # use the StringIO in send_data

    buffer = ''
    StringIO.open(buffer, 'w') { |string_io|
      range_request.write_content_to_output(info, string_io)
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
    headers[MediaPoll::HEADER_KEY_RESPONSE_FROM] = MediaPoll::HEADER_VALUE_RESPONSE_CACHE
  end

  def add_header_generated_remote
    headers[MediaPoll::HEADER_KEY_RESPONSE_FROM] = MediaPoll::HEADER_VALUE_RESPONSE_REMOTE
  end

  def add_header_generated_local
    headers[MediaPoll::HEADER_KEY_RESPONSE_FROM] = MediaPoll::HEADER_VALUE_RESPONSE_LOCAL
  end

  # request received
  def add_header_started(start_datetime)
    headers[MediaPoll::HEADER_KEY_RESPONSE_START] = start_datetime.httpdate
  end

  # from request received to data sent to client
  def add_header_total_elapsed(elapsed_seconds)
    headers[MediaPoll::HEADER_KEY_ELAPSED_TOTAL] = elapsed_seconds.to_s
  end

  # from job queue/generation start to job finished/generation finished
  def add_header_processing_elapsed(elapsed_seconds)
    headers[MediaPoll::HEADER_KEY_ELAPSED_PROCESSING] = elapsed_seconds.to_s
  end

  # from job finished/generation finished to data sent to client
  def add_header_waiting_elapsed(elapsed_seconds)
    headers[MediaPoll::HEADER_KEY_ELAPSED_WAITING] = elapsed_seconds.to_s
  end

end