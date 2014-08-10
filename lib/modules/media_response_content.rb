class MediaResponseContent
  public

  def initialize(generation_request, rails_request, user)
    @generation_request = generation_request
    @rails_request = rails_request
    @user = user
    @media_cacher = Settings.media_cache_tool
    @range_request = Settings.range_request
  end

  def perform

  end

  private

  def perform_audio
    target_file = @media_cacher.cached_audio_file_name(@generation_request)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_audio, target_file)

    headers[RangeRequest::HTTP_HEADER_ACCEPT_RANGES] = RangeRequest::HTTP_HEADER_ACCEPT_RANGES_BYTES
  end

  def perform_spectrogram
    target_file = @media_cacher.cached_spectrogram_file_name(@generation_request)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_spectrogram, target_file)
  end

  # Respond with audio range request.
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
      # return response code and headers with no content
      head_response(info[:response_code], info[:response_headers].merge(
          {
              content_transfer_encoding: 'binary',
              content_disposition: "inline; filename=\"#{info[:response_suggested_file_name]}\"",
              content_type: info[:file_media_type]
          }))

    else
      fail CustomErrors::UnprocessableEntityError, 'Unprocessable request'

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
    send_data buffer, *response_metadata(info)
  end

  # Responds with file content in file, using metadata from info.
  # @param [Hash] info
  def response_send_file(info)
    send_file info[:file_path], *response_metadata(info)
  end

  def response_metadata(info)
    {
        filename: info[:response_suggested_file_name],
        type: info[:file_media_type],
        disposition: 'inline',
        status: info[:response_code]
    }
  end

  def head_response(response_code, response_headers)
    #headers['Content-Transfer-Encoding'] = 'binary'
    #head :ok, content_length: File.size(full_path.first), content_type: options[:media_type], filename: suggested_file_name

    head response_code, response_headers
  end

  def create_spectrogram_resque
    resque_enqueue('cache_spectrogram', @generation_request)
  end

  def create_audio_resque
    resque_enqueue('cache_audio', @generation_request)
  end

  def resque_enqueue(media_request_type, options)
    Resque.enqueue(BawWorkers::MediaAction, media_request_type, options)
    headers['Retry-After'] = Time.zone.now.advance(seconds: 10).httpdate
    head :accepted, content_type: 'text/plain'
  end

end