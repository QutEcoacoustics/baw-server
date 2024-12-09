# frozen_string_literal: true

class MediaController < ApplicationController
  include Api::ControllerHelper

  skip_authorization_check only: [:show]

  attr_reader :audio_response_duration

  after_action :update_statistics

  def show
    # start timing request
    overall_start = Time.zone.now

    # normalize params and get access to rails request instance
    params.permit!
    request_params = CleanParams.perform(params.to_h)

    # should the response include content?
    is_head_request = request.head?

    # check authorization manually, take audio event into account
    @audio_recording, audio_event = authorize_custom(request_params, current_user)

    # can the audio recording be accessed?
    is_audio_ready = audio_recording_ready?(@audio_recording)

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
      raise CustomErrors::ItemNotFoundError, "Audio recording id #{@audio_recording.id} is not ready"
    elsif !is_supported_format && is_head_request
      head :not_acceptable
    elsif !is_supported_format && !is_head_request
      supported_types = Settings.supported_media_types
      msg = "Requested format #{requested_format} (#{requested_media_type}) is not acceptable. " \
            'It must be one of available_formats.'
      raise CustomErrors::NotAcceptableError.new(msg, supported_types)
    elsif is_supported_format && is_audio_ready

      category, defaults = Settings.media_category(requested_format)

      media_info = {
        category:,
        defaults:,
        format: requested_format,
        media_type: requested_media_type,
        timing_overall_start: overall_start
      }

      supported_media_response(@audio_recording, audio_event, media_info, request_params)
    else
      raise CustomErrors::BadRequestError, 'There was a problem with the request.'
    end
  end

  # GET /audio_recordings/:id/original
  def original
    # start timing request
    time_start = Time.zone.now

    # unlike a standard media request, the only parameter we allow here is an audio recording id
    # (:format is irrelevant because return mime is whatever mime the original recording is)
    request_params = params.slice(:audio_recording_id).permit(:audio_recording_id).to_h

    @audio_recording = AudioRecording.find(request_params[:audio_recording_id])
    do_authorize_instance(:original, @audio_recording)

    original_file_response(@audio_recording, request, time_start)
  end

  private

  def update_statistics
    return if request.head?
    return unless response.successful?

    # speculative fix for https://github.com/QutEcoacoustics/baw-server/issues/575
    # we sometimes see "ActiveRecord::ConnectionNotEstablished connection is closed " errors
    # in this function. Try wrapping in it's own connection
    ActiveRecord::Base.connection_pool.with_connection do
      case action_name.to_sym
      when :show
        return if audio_response_duration.nil?

        Statistics::AudioRecordingStatistics.increment_segment(@audio_recording, duration: audio_response_duration)

        if current_user.nil?
          Statistics::AnonymousUserStatistics.increment_segment(duration: audio_response_duration)
        else
          Statistics::UserStatistics.increment_segment(current_user, duration: audio_response_duration)
        end
      when :original
        Statistics::AudioRecordingStatistics.increment_original(@audio_recording)

        if current_user.nil?
          Statistics::AnonymousUserStatistics.increment_original(@audio_recording)
        else
          Statistics::UserStatistics.increment_original(current_user, @audio_recording)
        end
      else
        raise "Unsupported action #{action_name} in update_statistics"
      end
    end
  end

  def authorize_custom(request_params, user)
    # AT 2018-02-26: removed the following condition because it should be covered by standard abilities
    # # (!Access::Core.is_standard_user?(user) && !Access::Core.is_admin?(user))

    # AT 2019-11-07: Public access will allow auth to progress past this point
    # where as it used to be if there was no user, we'd stop here.
    # I'm still going to make sure actual users are confirmed though.
    raise CanCan::AccessDenied, 'Account not confirmed' if user.present? && !user.confirmed?

    audio_recording = auth_custom_audio_recording(request_params, action_name.to_sym)

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

  def supported_media_response(audio_recording, _audio_event, media_info, request_params)
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
      raise CustomErrors::BadRequestError, 'There was a problem with the request.'
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
        }
      )
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

    case media_info[:category]
    when :audio
      generation_request = generation_request.except(:window, :window_function, :colour)
      # check if audio file exists in cache
      cached_audio_info = audio_cached.path_info(generation_request)
      media_category = :audio

      existing_files, time_waiting_start, in_memory_file = create_media(media_category, cached_audio_info,
        generation_request)
      response_local_audio_segment(audio_recording, generation_request, existing_files, rails_request, range_request,
        time_start, time_waiting_start, in_memory_file:)
    when :image
      # check if spectrogram image file exists in cache
      cached_spectrogram_info = spectrogram_cached.path_info(generation_request)
      media_category = :spectrogram

      existing_files, time_waiting_start, in_memory_file = create_media(media_category, cached_spectrogram_info,
        generation_request)
      response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, range_request,
        time_start, time_waiting_start, in_memory_file:)
    end
  end

  # Used to return a whole original audio file, without transcoding. This represents a simplified execution path of a
  # standard media request.
  # Supports range requests (if asked for), otherwise uses the send_file mechanism
  def original_file_response(audio_recording, rails_request, time_start)
    # should the response include content?
    is_head_request = rails_request.head?

    # can the audio recording be accessed?
    is_audio_ready = audio_recording_ready?(audio_recording)

    # do initial checking
    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :accepted
    elsif !is_audio_ready && !is_head_request
      raise CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"
    end

    existing_files = audio_recording.original_file_paths

    if existing_files.empty?

      raise CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} can not be found on disk"
    end

    # add the header from timer start
    add_header_started(time_start)

    # add the data hash so downloads can be verified
    add_header_hash(audio_recording)
    # assume first file of returned files is correct
    file_path = existing_files.first
    download_options = {
      media_type: audio_recording.media_type,
      site_name: audio_recording.site.name,
      site_id: audio_recording.site.id,
      recorded_date: audio_recording.recorded_date,
      recording_duration: audio_recording.duration_seconds,
      recording_id: audio_recording.id,
      ext: Mime::Type.file_extension_of(audio_recording.media_type),
      file_path:,
      file_size: File.size(file_path),
      start_offset: 0,
      end_offset: audio_recording.duration_seconds,
      # provide our own name for the recording (normally generated in range request)
      suggested_file_name: audio_recording.friendly_name,
      disposition_type: :attachment
    }
    range_request = Settings.range_request

    # last param is time_waiting_start - we've spent zero time waiting because no transcoding was done
    download_file(nil, download_options, rails_request, range_request, time_start, 0)
  end

  def create_media(media_category, files_info, generation_request)
    # determine where media cutting and/ort spectrogram generation will occur
    is_processed_locally = Settings.process_media_locally?
    is_processed_by_resque = Settings.process_media_resque?
    processor = Settings.media_request_processor

    existing_files = files_info[:existing]
    expected_files = files_info[:possible]

    time_start_waiting = nil

    if existing_files.blank? && is_processed_locally
      add_header_generated_local
      existing_files = create_media_local(media_category, generation_request)

    elsif existing_files.blank? && is_processed_by_resque
      add_header_generated_remote

      Rails.logger.debug { "media_controller#create_media: Begin remote processing to create #{expected_files}" }
      result = create_media_resque(expected_files, media_category, generation_request)

      time_start_waiting = Time.zone.now

      if result[:in_memory_file]
        Rails.logger.debug { "media_controller#create_media: found file in fast cache #{expected_files}" }
        add_header_remote_and_fast_cache
        in_memory_file = result[:in_memory_file]
        return [[expected_files.first], time_start_waiting, in_memory_file]
      else

        Rails.logger.debug { "media_controller#create_media: Submitted processing job for #{expected_files}" }

        # poll disk for audio
        # will throw with a timeout if file does not appear on disk
        existing_files = MediaPoll.poll_media(expected_files, Settings.audio_tools_timeout_sec)

        Rails.logger.debug {
          "media_controller#create_media: Actual files from disk poll after remote processing #{existing_files}"
        }
      end
    elsif existing_files.present?
      add_header_cache
      add_header_processing_elapsed(0)
    end

    # check that there is at least one existing file
    existing_files = existing_files.compact # remove nils

    if existing_files.blank?
      # NB: this branch should never execute, as poll_media should throw if no files are found
      # and other branches make existing_file.blank? impossible
      Rails.logger.debug do
        "media_controller#create_media: No files matched, existing files: #{existing_files}, expected files: #{expected_files}"
      end

      msg1 = "Could not create #{media_category}"
      msg2 = "using #{processor}"
      msg3 = "from request #{generation_request}"
      raise BawAudioTools::Exceptions::AudioToolError, "#{msg1} #{msg2} #{msg3}"
    end

    time_start_waiting = Time.zone.now if time_start_waiting.nil?
    [existing_files, time_start_waiting, nil]
  end

  # Create a media request locally.
  # @param [Symbol] media_category
  # @param [Object] generation_request
  # @return [String] path to existing file
  def create_media_local(media_category, generation_request)
    start_time = Time.zone.now
    target_existing_paths = make_job(media_category, generation_request).perform_now
    end_time = Time.zone.now

    add_header_processing_elapsed(end_time - start_time)

    target_existing_paths
  end

  # Create a media request using resque.
  # @param [Symbol] media_category
  # @param [Object] generation_request
  # @return [Resque::Plugins::Status::Hash] job status
  def create_media_resque(expected_files, media_category, generation_request)
    start_time = Time.zone.now
    job = make_job(media_category, generation_request)
    case job.enqueue
    in ::BawWorkers::Jobs::ApplicationJob
      # default case
      job.job_id
    in false if !job.unique?
      # debounce
      logger.debug('Duplicate job debounced', job_id: job.job_id)
      job.job_id
    else
      logger.error('unhandled job enqueue failure', job:)
      raise "Failed to enqueue job: #{job}"
    end => job_id

    #existing_files = MediaPoll.poll_media(expected_files, Settings.audio_tools_timeout_sec)
    poll_result = MediaPoll.poll_resque_and_media(
      expected_files,
      media_category,
      generation_request,
      Settings.audio_tools_timeout_sec,
      job_id:
    )
    end_time = Time.zone.now

    add_header_processing_elapsed(end_time - start_time)

    poll_result
  end

  # @return [BawWorkers::Jobs::Media::AudioJob,BawWorkers::Jobs::Media::SpectrogramJob]
  def make_job(media_category, generation_request)
    case media_category
    when :audio
      BawWorkers::Jobs::Media::AudioJob.new(
        ::BawWorkers::Models::AudioRequest.new(generation_request)
      )
    when :spectrogram
      BawWorkers::Jobs::Media::SpectrogramJob.new(
        ::BawWorkers::Models::SpectrogramRequest.new(generation_request)
      )
    else
      raise "Invalid media type: #{media_category}"
    end
  end

  def response_local_spectrogram(audio_recording, generation_request, existing_files, rails_request, _range_request,
                                 time_start, time_waiting_start, in_memory_file:)
    options = generation_request

    response_extra_info = "#{options[:channel]}_#{options[:sample_rate]}_#{options[:window]}_#{options[:colour]}"
    suggested_file_name = NameyWamey.create_audio_recording_name(audio_recording, options[:start_offset],
      options[:end_offset], response_extra_info, options[:format])

    existing_file = existing_files.first
    content_length = in_memory_file.nil? ? File.size(existing_file) : in_memory_file.size

    add_header_length(content_length)

    # add overall time taken and waiting time elapsed header
    time_stop = Time.zone.now
    add_header_total_elapsed(time_stop - time_start)
    add_header_waiting_elapsed(time_stop - time_waiting_start)

    if rails_request.head?
      head_response_inline(:ok, { content_length: }, options[:media_type], suggested_file_name, 'inline')
    elsif !in_memory_file.nil?
      info = {
        response_suggested_file_name: suggested_file_name,
        response_disposition_type: 'inline',
        file_media_type: options[:media_type],
        response_code: :ok
      }
      response_send_data(in_memory_file, info)
    else
      info = {
        file_path: existing_file,
        response_suggested_file_name: suggested_file_name,
        response_disposition_type: 'inline',
        file_media_type: options[:media_type],
        response_code: :ok
      }
      response_send_file(info)

    end
  end

  def response_local_audio_segment(audio_recording, generation_request, existing_files, rails_request, range_request,
                                   time_start, time_waiting_start, in_memory_file:)
    @audio_response_duration = generation_request[:end_offset] - generation_request[:start_offset]
    file_path = existing_files.first
    download_options = {
      media_type: generation_request[:media_type],
      site_name: audio_recording.site.name,
      site_id: audio_recording.site.id,
      recorded_date: audio_recording.recorded_date,
      recording_duration: audio_recording.duration_seconds,
      recording_id: audio_recording.id,
      ext: generation_request[:format],
      file_path:,
      file_size: in_memory_file&.size || File.size(file_path),
      start_offset: generation_request[:start_offset],
      end_offset: generation_request[:end_offset]
    }

    # just always read file into memory
    in_memory_file = File.binread(file_path) if in_memory_file.nil?

    download_file(in_memory_file, download_options, rails_request, range_request, time_start, time_waiting_start)
  end

  # Respond with audio range request.
  # @param [Hash] options
  # @param [ActionDispatch::Request] rails_request
  # @param [RangeRequest] range_request
  def download_file(buffer, options, rails_request, range_request, time_start, time_waiting_start)
    #raise ArgumentError, 'File does not exist on disk' if full_path.blank?
    # are HEAD requests supported? Yes
    # more info: http://patshaughnessy.net/2010/10/11/activerecord-with-large-result-sets-part-2-streaming-data
    # http://blog.sparqcode.com/2012/02/04/streaming-data-with-rails-3-1-or-3-2/
    # http://stackoverflow.com/questions/3507594/ruby-on-rails-3-streaming-data-through-rails-to-client
    # ended up using StringIO as a MemoryStream to store part of audio file requested.

    # headers[RangeRequest::HTTP_HEADER_ACCEPT_RANGES] = RangeRequest::HTTP_HEADER_ACCEPT_RANGES_BYTES
    # content length is added by RangeRequest
    file_path = options[:file_path]
    info = range_request.build_response(options, rails_request)

    headers.merge!(info[:response_headers])

    is_head_request = rails_request.head?
    has_content = info[:response_has_content]
    is_range = info[:response_is_range]

    info[:response_has_content] = false if is_head_request

    # add overall time taken header
    time_stop = Time.zone.now
    add_header_total_elapsed(time_stop - time_start)
    add_header_waiting_elapsed(time_stop - time_waiting_start)

    if has_content && is_range
      buffer = write_to_response_stream(buffer, file_path, info, range_request)
      response_send_data(buffer, info)

    elsif has_content && !is_range
      if buffer.nil?
        response_send_file(info)
      else
        response_send_data(buffer, info)
      end

    elsif !has_content
      head_response_inline(
        info[:response_code],
        info[:response_headers],
        info[:file_media_type],
        info[:response_suggested_file_name],
        info[:response_disposition_type]
      )
    else
      raise CustomErrors::UnprocessableEntityError, 'There was a problem with the request.'

    end
  end

  def write_to_response_stream(in_buffer, file_path, info, range_request)
    # write audio data from the file to a stringIO
    # use the StringIO in send_data

    # must be a mutable string
    out_buffer = BawWorkers::IO.new_binary_string
    StringIO.open(out_buffer, 'w') do |string_io|
      if in_buffer.nil?
        range_request.write_file_content_to_output(file_path, info, string_io)
      else
        range_request.write_content_to_output(in_buffer, info, string_io)
      end
    end
    out_buffer
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
    send_file(info[:file_path], response_binary_metadata(info))
  end

  def response_binary_metadata(info)
    {
      filename: info[:response_suggested_file_name],
      type: info[:file_media_type],
      content_type: info[:file_media_type],
      disposition: info[:response_disposition_type],
      status: info[:response_code]
    }
  end

  def head_response(response_code, response_headers)
    #headers['Content-Transfer-Encoding'] = 'binary'
    #head :ok, content_length: File.size(full_path.first), content_type: options[:media_type], filename: suggested_file_name

    head response_code, response_headers
  end

  def head_response_inline(response_code, response_headers, content_type, suggested_name, disposition_type)
    # return response code and headers with no content
    head_response response_code, response_headers.merge(
      content_type:,
      content_transfer_encoding: 'binary',
      content_disposition: "#{disposition_type}; filename=\"#{suggested_name}\"",
      filename: suggested_name
    )
  end

  def add_header_cache
    headers[MediaPoll::HEADER_KEY_RESPONSE_FROM] = MediaPoll::HEADER_VALUE_RESPONSE_CACHE
  end

  def add_header_remote_and_fast_cache
    headers[MediaPoll::HEADER_KEY_RESPONSE_FROM] = MediaPoll::HEADER_VALUE_RESPONSE_REMOTE_CACHE
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

  # Adds a hash header to the response so that it is possible to verify downloaded files.
  # Should only be used for whole original files
  # Based on:
  # - https://tools.ietf.org/id/draft-cavage-http-signatures-08.html
  # - https://tools.ietf.org/html/rfc3230#section-4.3
  # @param AudioRecording
  # @return String
  def add_header_hash(audio_recording)
    protocol, value = audio_recording.split_file_hash
    headers['Digest'] = "#{protocol}=#{value}"
  end
end
