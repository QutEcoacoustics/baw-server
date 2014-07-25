class MediaController < ApplicationController
  #load_and_authorize_resource :audio_recording, only: [:show]
  skip_authorization_check only: [:show]

  AUDIO_MEDIA_TYPES = [Mime::Type.lookup('audio/webm'), Mime::Type.lookup('audio/webma'),
                       Mime::Type.lookup('audio/ogg'), Mime::Type.lookup('audio/oga'),
                       Mime::Type.lookup('audio/mp3'), Mime::Type.lookup('audio/mpeg'),
                       Mime::Type.lookup('audio/wav'), Mime::Type.lookup('audio/x-wav'),
                       Mime::Type.lookup('audio/x-flac')]

  IMAGE_MEDIA_TYPES = [Mime::Type.lookup('image/png')]

  OFFSET_REGEXP = /^\d+(\.\d{1,3})?$/ # passes '111', '11.123'

  MEDIA_PROCESSOR_LOCAL = 'local'
  MEDIA_PROCESSOR_RESQUE = 'resque'

  def show
    # ensure all param keys are symbols rather than strings
    request_params_mixed = params.dup.symbolize_keys
    rails_request = request

    # convert all params to snake case
    request_params = ActiveSupport::HashWithIndifferentAccess.new
    request_params_mixed.each do |key, value|
      request_params[key.to_s.underscore] = value
    end

    # check authorisation manually, take audio event into account
    audio_recording = authorise_custom(request_params, current_user)

    # set up resources to process request
    @range_request = Settings.range_request
    @media_cacher = Settings.media_cache_tool

    @available_text_formats = Settings.available_formats.text
    @available_audio_formats = Settings.available_formats.audio
    @available_image_formats = Settings.available_formats.image

    @default_audio = Settings.cached_audio_defaults
    @default_spectrogram = Settings.cached_spectrogram_defaults

    @available_formats = @available_text_formats + @available_audio_formats + @available_image_formats

    is_audio_ready = audio_recording.status == 'ready'
    is_head_request = rails_request.head?
    is_available_format = @available_formats.include?(request_params[:format].downcase)

    # where will this request be processed
    media_processor = Settings.media_request_processor
    @is_processed_locally = media_processor == MEDIA_PROCESSOR_LOCAL
    @is_processed_by_resque = media_processor == MEDIA_PROCESSOR_RESQUE

    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :accepted
    elsif !is_audio_ready && !is_head_request
      fail CustomErrors::ItemNotFoundError, 'Audio recording is not ready'
    elsif !is_available_format && is_head_request
      head :unsupported_media_type_error
    elsif !is_available_format && !is_head_request
      fail CustomErrors::UnsupportedMediaTypeError.new(@available_formats), 'Requested format is invalid. It must be one of available_formats.'
    elsif is_available_format && is_audio_ready
      process_media_request(audio_recording, request_params, rails_request)
    else
      fail ActiveResource::BadRequest
    end
  end

  private

  def auth_custom_offsets(request_params, audio_recording, audio_event)

    # check offsets are within range
    if request_params.include?(:start_offset)
      start_offset = request_params[:start_offset].to_f
    else
      start_offset = 0.0
    end

    if request_params.include?(:end_offset)
      end_offset = request_params[:end_offset].to_f
    else
      end_offset = audio_recording.duration_seconds.to_f
    end

    audio_event_start = audio_event.start_time_seconds
    audio_event_end = audio_event.end_time_seconds

    allowable_padding = 5

    allowable_start_offset = audio_event_start - allowable_padding
    allowable_end_offset = audio_event_end + allowable_padding

    if start_offset < allowable_start_offset || end_offset > allowable_end_offset
      fail CanCan::AccessDenied,
           'Permission denied to audio recording, offsets were too far outside given audio recording (including padding).'
    end

  end

  def authorise_custom(request_params, user)

    # Can't do anything if not logged in, not in user or admin role, or not confirmed
    if user.blank? || (!user.has_role?(:user) && !user.has_role?(:admin)) || !user.confirmed?
      fail CanCan::AccessDenied, 'Anonymous users, non-admin and non-users, or unconfirmed users cannot access media.'
    end

    audio_recording = auth_custom_audio_recording(request_params)

    unless request_params[:audio_event_id].blank?
      audio_event = auth_custom_audio_event(request_params, audio_recording)
      auth_custom_offsets(request_params, audio_recording, audio_event)
    end

    audio_recording
  end

  # Process a request.
  # @param [AudioRecording] audio_recording
  # @param [Hash] request_params
  # @param [ActionDispatch::Request] rails_request
  def process_media_request(audio_recording, request_params, rails_request)
    parsed_options = parse_media_request(audio_recording, request_params, rails_request)
    parsed_options = check_request_parameters(audio_recording, parsed_options, rails_request)

    # an error ocurred when checking parameters
    # render has already been called, don't do anything else.
    is_audio = AUDIO_MEDIA_TYPES.include?(parsed_options[:media_type])
    is_image = IMAGE_MEDIA_TYPES.include?(parsed_options[:media_type])

    if is_audio
      request_type =:audio
      request_defaults = @default_audio
    elsif is_image
      request_type =:image
      request_defaults = @default_spectrogram
    else
      request_type =:json
      request_defaults = {}
    end

    if request_type == :json
      response_options = build_json_response(audio_recording, parsed_options, request_params, rails_request)
      json_response(audio_recording, response_options, request_params, rails_request)
    else
      response_options = build_response(
          audio_recording, parsed_options,
          request_params, rails_request,
          request_type, request_defaults)

      if request_type == :audio
        audio_response(audio_recording, response_options, request_params, rails_request)
      elsif request_type == :image
        spectrogram_response(audio_recording, response_options, request_params, rails_request)
      end
    end
  end

  # Parse a request.
  # @param [AudioRecording] audio_recording
  # @param [Hash] request_params
  # @param [ActionDispatch::Request] rails_request
  # @return [Hash] Parsed request options
  def parse_media_request(audio_recording, request_params, rails_request)
    options = Hash.new
    options[:datetime] = audio_recording.recorded_date
    # use audio recording original file name if available
    options[:original_format] = File.extname(audio_recording.original_file_name) unless audio_recording.original_file_name.blank?
    # get the extension for the mime type if original file name is not available
    options[:original_format] = '.' + Mime::Type.lookup(audio_recording.media_type).to_sym.to_s if options[:original_format].blank?
    # date and time are for finding the original audio file
    options[:datetime_with_offset] = audio_recording.recorded_date
    options[:original_sample_rate] = audio_recording.sample_rate_hertz

    if request_params.include?(:start_offset)
      options[:start_offset] = request_params[:start_offset].to_f
    else
      options[:start_offset] = 0.0
    end

    if request_params.include?(:end_offset)
      options[:end_offset] = request_params[:end_offset].to_f
    else
      options[:end_offset] = audio_recording.duration_seconds.to_f
    end

    options[:uuid] = audio_recording.uuid
    options[:id] = audio_recording.id
    # .to_s on mime:type gets the media type
    # .to_sym gets the extension
    options[:media_type] = Mime::Type.lookup_by_extension(request_params[:format]).to_s
    options[:format] = request_params[:format]

    options
  end

  # Check request parameters.
  # @param [AudioRecording] audio_recording
  # @param [Hash] request_params
  # @param [ActionDispatch::Request] rails_request
  # @return [Hash] Modified request parameters
  def check_request_parameters(audio_recording, request_params, rails_request)
    format = request_params[:format]
    start_offset = request_params[:start_offset].to_s
    end_offset = request_params[:end_offset].to_s
    audio_duration = audio_recording.duration_seconds

    if format == 'json'
      start_offset ||= '0'
      end_offset ||= audio_duration.to_s
    else
      if start_offset.blank? &&end_offset.blank?
        start_offset = '0'
        if audio_duration < 600
          end_offset = audio_duration.to_s
        else
          end_offset = '600'
        end
      elsif end_offset.blank?
        end_offset = audio_duration.to_s
      elsif start_offset.blank?
        start_offset = '0'
      end
      if end_offset.to_i - start_offset.to_i > 600
        msg = "Maximum range is 600 seconds, you requested #{end_offset.to_i - start_offset.to_i} seconds between start_offset=#{start_offset} and end_offset=#{end_offset}"
        fail BawAudioTools::SegmentRequestTooLong.new(msg)
        # render json: {code: 416,
        #               phrase: 'Requested Range Not Satisfiable',
        #               message: msg},
        #        status: :requested_range_not_satisfiable
        # is_error_state = true
      end
    end

    if !(start_offset=~OFFSET_REGEXP)
      fail CustomErrors::UnprocessableEntityError, "start_offset parameter (#{start_offset}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"
      # render json: {code: 422,
      #               phrase: 'Unprocessable Entity',
      #               message: "start_offset parameter (#{start_offset}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"},
      #        status: :unprocessable_entity
      # is_error_state = true
    elsif !(end_offset=~OFFSET_REGEXP)
      fail CustomErrors::UnprocessableEntityError, "end_offset parameter (#{end_offset}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"
      #       render json: {code: 422,
      #               phrase: 'Unprocessable Entity',
      #               message: "end_offset parameter (#{end_offset}) must be a decimal number indicating seconds (maximum precision milliseconds, e.g., 1.234)"},
      #        status: :unprocessable_entity
      # is_error_state = true
    elsif end_offset.to_i > audio_duration
      fail CustomErrors::UnprocessableEntityError, "end_offset parameter (#{end_offset}) must be a smaller than the duration of the audio recording (#{audio_duration})"
      # render json: {code: 416,
      #               phrase: 'Requested Range Not Satisfiable',
      #               message: "end_offset parameter (#{end_offset}) must be a smaller than the duration of the audio recording (#{audio_duration})"},
      #        status: :requested_range_not_satisfiable
      # is_error_state = true
    elsif start_offset.to_i >= audio_duration
      fail CustomErrors::UnprocessableEntityError, "start_offset parameter (#{start_offset}) must be a smaller than the duration of the audio recording (#{audio_duration})"
      # render json: {code: 416,
      #               phrase: 'Requested Range Not Satisfiable',
      #               message: "start_offset parameter (#{start_offset}) must be a smaller than the duration of the audio recording (#{audio_duration})"},
      #        status: :requested_range_not_satisfiable
      # is_error_state = true
    elsif start_offset.to_i >= end_offset.to_i
      fail CustomErrors::UnprocessableEntityError, "start_offset parameter (#{start_offset}) must be a smaller than end_offset (#{end_offset})"
      # render json: {code: 416,
      #               phrase: 'Requested Range Not Satisfiable',
      #               message: "start_offset parameter (#{start_offset}) must be a smaller than end_offset (#{end_offset})"},
      #        status: :requested_range_not_satisfiable
      # is_error_state = true
    end

    request_params[:start_offset] = start_offset.to_f
    request_params[:end_offset] = end_offset.to_f

    request_params
  end

  # Get the available formats.
  # @param [AudioRecording] audio_recording
  # @param [Array<String>] formats
  # @param [Numeric] start_offset
  # @param [Numeric] end_offset
  # @param [Object] defaults
  # @return [Hash] Available formats
  def get_available_formats(audio_recording, formats, start_offset, end_offset, defaults = {})
    result = {}

    formats.each do |format|
      format_key = format.to_s
      result[format_key] = defaults.dup
      result[format_key].delete 'format'
      result[format_key][:extension] = format_key
      result[format_key][:start_offset] = start_offset
      result[format_key][:end_offset] = end_offset
      result[format_key]['mime_type'] = Mime::Type.lookup_by_extension(format).to_s
      result[format_key]['url'] = audio_recording_media_path(
          audio_recording,
          format: format,
          start_offset: start_offset,
          end_offset: end_offset)
    end

    result
  end

  # Build response options
  # @param [AudioRecording] audio_recording
  # @param [Hash] options
  # @param [Hash] request_params
  # @param [ActionDispatch::Request] rails_request
  # @param [Symbol] request_type
  # @param [Hash] defaults
  # @return [Hash] Response options.
  def build_response(audio_recording, options, request_params, rails_request, request_type, defaults)

    options[:format] = request_params[:format] || defaults.extension
    options[:channel] = (request_params[:channel] || defaults.channel).to_i

    # if sample rate not given, default to audio recording native sample rate
    #options[:sample_rate] = (request_params[:sample_rate] || audio_recording.sample_rate_hertz).to_i

    if request_type == :image
      options[:window] = (request_params[:window] || defaults.window).to_i
      options[:colour] = (request_params[:colour] || defaults.colour).to_s

      # for now, use the sample rate from the settings file if none given
      options[:sample_rate] = (request_params[:sample_rate] || @default_spectrogram.sample_rate).to_i

    elsif request_type == :audio

      # for now, use the sample rate from the settings file if none given
      options[:sample_rate] = (request_params[:sample_rate] || @default_audio.sample_rate).to_i

    end

    @media_cacher.audio.check_offsets(
        {duration_seconds: audio_recording.duration_seconds},
        defaults.min_duration_seconds,
        defaults.max_duration_seconds,
        options
    )

    options
  end

  # Build json response.
  # @param [AudioRecording] audio_recording
  # @param [Hash] options
  # @param [Hash] request_params
  # @param [ActionDisptach::Request] rails_request
  # @return [Hash] Json response
  def build_json_response(audio_recording, options, request_params, rails_request)

    options[:available_audio_formats] =
        get_available_formats(audio_recording, @available_audio_formats, request_params[:start_offset], request_params[:end_offset], @default_audio)
    options[:available_image_formats] =
        get_available_formats(audio_recording, @available_image_formats, request_params[:start_offset], request_params[:end_offset], @default_spectrogram)
    options[:available_text_formats] =
        get_available_formats(audio_recording, @available_text_formats, request_params[:start_offset], request_params[:end_offset])

    options.delete :datetime_with_offset
    options[:format] = 'json'

    options
  end


  # Respond to a request for audio.
  # @param [AudioRecording] audio_recording
  # @param [Hash] options
  # @param [Hash] request_params
  # @param [ACtionDisptach::Request] rails_request
  def audio_response(audio_recording, options, request_params, rails_request)

    target_file = @media_cacher.cached_audio_file_name(options)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_audio, target_file)

    headers[RangeRequest::HTTP_HEADER_ACCEPT_RANGES] = RangeRequest::HTTP_HEADER_ACCEPT_RANGES_BYTES

    if @is_processed_locally || !target_existing_paths.blank?

      file_path = @media_cacher.create_audio_segment(options).first

      download_options = {
          media_type: options[:media_type],
          site_name: audio_recording.site.name,
          site_id: audio_recording.site.id,
          recorded_date: audio_recording.recorded_date,
          recording_duration: audio_recording.duration_seconds,
          recording_id: audio_recording.id,
          ext: options[:format],
          file_path: file_path,
          start_offset: options[:start_offset],
          end_offset: options[:end_offset]
      }

      download_file(download_options, rails_request)

    elsif @is_processed_by_resque
      resque_enqueue('cache_audio', options)
    end

  end

  # @param [AudioRecording] audio_recording
  # @param [Hash] options
  # @param [Hash] request_params
  def spectrogram_response(audio_recording, options, request_params, rails_request)

    target_file = @media_cacher.cached_spectrogram_file_name(options)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_spectrogram, target_file)

    if @is_processed_locally || !target_existing_paths.blank?
      # either the request will be processed locally or the file already exists

      # file will be generated if it doesn't exist, blocking the request until finished
      full_path = @media_cacher.generate_spectrogram(options)
      headers['Content-Length'] = File.size(full_path.first).to_s

      response_extra_info = "#{options[:channel]}_#{options[:sample_rate]}_#{options[:window]}_#{options[:colour]}"
      suggested_file_name = NameyWamey.create_audio_recording_name(audio_recording, options[:start_offset], options[:end_offset], response_extra_info, options[:format])

      if rails_request.head?
        head_response(:ok, {
            content_length: File.size(full_path.first),
            content_type: options[:media_type],
            filename: suggested_file_name,
            content_transfer_encoding: 'binary',
            content_disposition: "inline; filename=\"#{suggested_file_name}\""
        })
      else
        send_file full_path.first,
                  stream: true,
                  buffer_size: 4096,
                  disposition: 'inline',
                  type: options[:media_type],
                  content_type: options[:media_type],
                  filename: suggested_file_name
      end

    elsif @is_processed_by_resque
      resque_enqueue('cache_spectrogram', options)
    end
  end

  # @param [AudioRecording] audio_recording
  # @param [Hash] options
  # @param [Hash] request_params
  # @param [ActionDisptach::Request] rails_request
  def json_response(audio_recording, options, request_params, rails_request)

    #json_result = create_json_data_response(:ok, options).to_json
    json_result = options.to_json

    headers['Content-Length'] = json_result.size.to_s

    if rails_request.head?
      head_response(:ok, {
          content_length: json_result.size.to_s,
          content_type: options[:media_type]
      })
    else
      render json: json_result, content_length: json_result.size.to_s
    end
  end

  def resque_enqueue(media_request_type, options)
    Resque.enqueue(BawWorkers::MediaAction, media_request_type, options)
    headers['Retry-After'] = Time.zone.now.advance(seconds: 10).httpdate
    head :accepted, content_type: 'text/plain'
  end

  # @param [Hash] options
  # @param [ActionDispatch::Request] rails_request
  def download_file(options, rails_request)
    #raise ArgumentError, 'File does not exist on disk' if full_path.blank?
    # are HEAD requests supported?
    # more info: http://patshaughnessy.net/2010/10/11/activerecord-with-large-result-sets-part-2-streaming-data
    # http://blog.sparqcode.com/2012/02/04/streaming-data-with-rails-3-1-or-3-2/
    # http://stackoverflow.com/questions/3507594/ruby-on-rails-3-streaming-data-through-rails-to-client
    # ended up using StringIO as a MemoryStream to store part of audio file requested.

    info = @range_request.build_response(options, rails_request)

    headers.merge!(info[:response_headers])

    if rails_request.head?
      info[:response_has_content] = false
    end

    if info[:response_has_content]
      if info[:response_is_range]

        # write audio data from the file to a stringIO
        # use the StringIO in send_data

        buffer = ''
        StringIO.open(buffer, 'w') { |string_io|
          @range_request.write_content_to_output(info, string_io)
        }

        send_data buffer,
                  filename: info[:response_suggested_file_name],
                  type: info[:file_media_type],
                  disposition: 'inline',
                  status: info[:response_code]

      else

        send_file info[:file_path],
                  filename: info[:response_suggested_file_name],
                  type: info[:file_media_type],
                  disposition: 'inline',
                  status: info[:response_code]
        #stream: true,
        #buffer_size: 4096
      end
    else
      # return response code and headers with no content
      head_response(info[:response_code], info[:response_headers].merge(
          {
              content_transfer_encoding: 'binary',
              content_disposition: "inline; filename=\"#{info[:response_suggested_file_name]}\"",
              content_type: info[:file_media_type]
          }))
    end
  end

  def head_response(response_code, response_headers)
    #headers['Content-Transfer-Encoding'] = 'binary'
    #head :ok, content_length: File.size(full_path.first), content_type: options[:media_type], filename: suggested_file_name

    head response_code, response_headers
  end

end