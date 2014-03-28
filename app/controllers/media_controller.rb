class MediaController < ApplicationController

  #load_resource :project, only: [:audio, :spectrogram]
  #load_resource :site, only: [:audio, :spectrogram]
  load_and_authorize_resource :audio_recording, only: [:show]

  before_filter :check_offset_format

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

    log_options(params, '#show method start')

    @media_processor = Settings.media_request_processor
    @media_cacher = BawAudioTools::MediaCacher.new(Settings.paths.temp_files)

    @available_text_formats = Settings.available_formats.text
    @available_audio_formats = Settings.available_formats.audio
    @available_image_formats = Settings.available_formats.image

    #default_dataset = Settings.cached_dataset_defaults

    @available_formats = @available_text_formats.concat(@available_audio_formats).concat(@available_image_formats)

    is_audio_ready = @audio_recording.status == 'ready'
    is_head_request = request.head?
    is_available_format = @available_formats.include?(params[:format].downcase)

    if !is_audio_ready && is_head_request
      # TODO:  Unprocessable Entity does not seem like the right response here
      head status: :unprocessable_entity
    elsif !is_audio_ready && !is_head_request
      render json: {error: 'Audio recording is not ready'}.to_json, status: :unprocessable_entity
    elsif !is_available_format && is_head_request
      head status: :unsupported_media_type
    elsif !is_available_format && !is_head_request
      render json: {error: 'Requested format is invalid. It must be one of available_formats.', available_formats: @available_formats}.to_json, status: :unsupported_media_type
    elsif is_available_format && is_audio_ready
      log_options(params, '#show audio recording ready')
      parse_media_request(@audio_recording, params)
    else
      render json: {error: 'Invalid request'}.to_json, status: :bad_request
    end
  end

  def get_available_formats(audio_recording, formats, start_offset, end_offset, defaults)

    result = {}

    formats.each do |format|
      format_key = format.to_s
      result[format_key] = defaults.clone
      result[format_key].delete 'format'
      result[format_key][:storage_format] = format_key
      result[format_key]['mime_type'] = Mime::Type.lookup_by_extension(format).to_s
      result[format_key]['url'] = audio_recording_media_path(audio_recording,
                                                             format: format,
                                                             start_offset: start_offset,
                                                             end_offset: end_offset)
    end

    result
  end

  private

  def parse_media_request(audio_recording, request_params)
    options = Hash.new
    options[:datetime] = audio_recording.recorded_date
    # use audio recording original file name if available
    options[:original_format] = File.extname(audio_recording.original_file_name) unless audio_recording.original_file_name.blank?
    # get the extension for the mime type if original file name is not available
    options[:original_format] = '.' + Mime::Type.lookup(audio_recording.media_type).to_sym.to_s if options[:original_format].blank?
    # date and time are for finding the original audio file
    options[:datetime_with_offset] = audio_recording.recorded_date

    log_options(options, '#show format is image or audio')

    options[:start_offset] = (request_params[:start_offset] || 0).to_f
    options[:end_offset] = (request_params[:end_offset] || audio_recording.duration_seconds).to_f
    options[:uuid] = audio_recording.uuid
    options[:id] = audio_recording.id
    # .to_s on mime:type gets the media type
    # .to_sym gets the extension
    options[:media_type] = Mime::Type.lookup_by_extension(request_params[:format]).to_s

    if AUDIO_MEDIA_TYPES.include?(options[:media_type])
      audio_response(audio_recording, options, request_params)
    elsif  IMAGE_MEDIA_TYPES.include?(options[:media_type])
      spectrogram_response(audio_recording, options, request_params)
    else
      json_response(audio_recording, options, request_params)
    end
  end

  def audio_response(audio_recording, options, request_params)

    default_audio = Settings.cached_audio_defaults

    options[:format] = request_params[:format] || default_audio.storage_format
    options[:channel] = (request_params[:channel] || default_audio.channel).to_i
    options[:sample_rate] = (request_params[:sample_rate] || default_audio.sample_rate).to_i

    log_options(options, '#show format is audio')

    @media_cacher.audio.check_offsets(
        {duration_seconds: audio_recording.duration_seconds},
        default_audio.min_duration_seconds,
        default_audio.max_duration_seconds,
        options
    )

    log_options(options, '#show after check offsets for audio')

    target_file = @media_cacher.cached_audio_file_name(options)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_audio, target_file)

    if @media_processor == MEDIA_PROCESSOR_LOCAL || !target_existing_paths.blank?

      file_path = @media_cacher.create_audio_segment(options).first

      download_file(
          {
              media_type: options[:media_type],
              site_name: audio_recording.site.name,
              recorded_date: audio_recording.recorded_date,
              recording_duration: audio_recording.duration_seconds,
              ext: options[:format],
              file_path: file_path,
              start_offset: options[:start_offset],
              end_offset: options[:end_offset]
          })
    elsif @media_processor == MEDIA_PROCESSOR_RESQUE
      resque_enqueue('cache_audio', options)
    end

  end

  def spectrogram_response(audio_recording, options, request_params)

    default_spectrogram = Settings.cached_spectrogram_defaults

    options[:format] = request_params[:format] || default_spectrogram.storage_format
    options[:channel] = (request_params[:channel] || default_spectrogram.channel).to_i
    options[:sample_rate] = (request_params[:sample_rate] || default_spectrogram.sample_rate).to_i
    options[:window] = (request_params[:window] || default_spectrogram.window).to_i
    options[:colour] = (request_params[:colour] || default_spectrogram.colour).to_s

    log_options(options, '#show format is image')

    @media_cacher.audio.check_offsets(
        {duration_seconds: audio_recording.duration_seconds},
        default_spectrogram.min_duration_seconds,
        default_spectrogram.max_duration_seconds,
        options
    )

    log_options(options, '#show after check offsets for image')

    target_file = @media_cacher.cached_spectrogram_file_name(options)
    target_existing_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.cache_spectrogram, target_file)

    if @media_processor == MEDIA_PROCESSOR_LOCAL || !target_existing_paths.blank?
      # either the request will be processed locally or the file already exists

      # file will be generated if it doesn't exist, blocking the request until finished
      full_path = @media_cacher.generate_spectrogram(options)
      headers['Content-Length'] = File.size(full_path.first).to_s
      send_file full_path.first, stream: true, buffer_size: 4096, disposition: 'inline', type: options[:media_type], content_type: options[:media_type]

    elsif @media_processor == MEDIA_PROCESSOR_RESQUE
      resque_enqueue('cache_spectrogram', options)
    end
  end

  def json_response(audio_recording, options, request_params)

    default_audio = Settings.cached_audio_defaults
    default_spectrogram = Settings.cached_spectrogram_defaults
    default_text = {}

    options[:available_audio_formats] =
        get_available_formats(audio_recording, @available_audio_formats, request_params[:start_offset], request_params[:end_offset], default_audio)
    options[:available_image_formats] =
        get_available_formats(audio_recording, @available_image_formats, request_params[:start_offset], request_params[:end_offset], default_spectrogram)
    options[:available_text_formats] =
        get_available_formats(audio_recording, @available_text_formats, request_params[:start_offset], request_params[:end_offset], default_text)

    options.delete :datetime_with_offset
    options[:format] = 'json'

    json_result = options.to_json

    if request.head?
      head status: :ok, content_length: json_result.size
    else
      headers['Content-Length'] = json_result.size.to_s
      render json: json_result
    end
  end

  def resque_enqueue(media_request_type, options)
    Resque.enqueue(BawWorkers::MediaAction, media_request_type, options)
    headers['Retry-After'] = Time.zone.now.advance(seconds: 10).httpdate
    head status: :accepted, content_type: 'text/plain'
  end

  def download_file(options)
    #raise ArgumentError, 'File does not exist on disk' if full_path.blank?
    # are HEAD requests supported?
    # more info: http://patshaughnessy.net/2010/10/11/activerecord-with-large-result-sets-part-2-streaming-data
    # http://blog.sparqcode.com/2012/02/04/streaming-data-with-rails-3-1-or-3-2/
    # http://stackoverflow.com/questions/3507594/ruby-on-rails-3-streaming-data-through-rails-to-client
    # ended up using StringIO as a MemoryStream to store part of audio file requested.

    log_options(options, '#download_file method start')

    info = RangeRequest.process_request(options, request)

    if info[:response_has_content]
      if info[:response_is_range]
        info = RangeRequest.prepare_response_partial(info)

        info[:response_headers].each do |key, value|
          headers[key.to_s.dasherize.split('-').each { |v| v[0] = v[0].chr.upcase }.join('-')] = value.to_s
        end

        # write audio data from the file to a stringIO
        # use the StringIO in send_data

        buffer = ''
        StringIO.open(buffer, 'w') { |string_io|
          RangeRequest.write_content_to_output(info, string_io)
        }

        send_data buffer,
                  filename: info[:response_suggested_file_name],
                  type: info[:file_media_type],
                  disposition: 'inline',
                  status: info[:response_code]

        # seems this can't be done with render - doesn't like it
        # !! Unexpected error while processing request: undefined method `each' for 208504:Fixnum
        # !! Unexpected error while processing request: deadlock; recursive locking

        #render text: proc { |response, output|
        #  1000.times do |i|
        #    output.write("This is line #{i}\n")
        #  end
        #}

        #render text: proc { |response, output|  RangeRequest.write_partial_to_response(info, response, output) }

        # use self.response_body instead, apparently

        #erroneous_call_to_proc = false
        #self.response_body = proc { |response, output|
        #  unless erroneous_call_to_proc
        #    1000.times do |i|
        #      output.write("This is line #{i}\n")
        #    end
        #  end
        #  erroneous_call_to_proc = true
        #}


        #self.response_body = Enumerator.new do |y|
        #  1000.times do |i|
        #    y << "This is line #{i}\n"
        #  end
        #end

      else
        info = RangeRequest.prepare_response_entire(info)

        info[:response_headers].each do |key, value|
          headers[key.to_s.dasherize.split('-').each { |v| v[0] = v[0].chr.upcase }.join('-')] = value.to_s
        end

        #info.response_headers.each do |key, value|
        #  response.headers[key] = value
        #end

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
      head info[:response_code], info[:response_headers]
    end
  end

  def check_offset_format
    if params[:format] == 'json'
      params[:start_offset] ||= '0'
      params[:end_offset] ||= @audio_recording.duration_seconds.to_s
    else
      if params[:start_offset].blank? && params[:end_offset].blank?
        params[:start_offset] = '0'
        if @audio_recording.duration_seconds < 600
          params[:end_offset] = @audio_recording.duration_seconds.to_s
        else
          params[:end_offset] = '600'
        end
      elsif params[:end_offset].blank?
        params[:end_offset] = @audio_recording.duration_seconds.to_s
      elsif params[:start_offset].blank?
        params[:start_offset] = '0'
      end
      if params[:end_offset].to_i - params[:start_offset].to_i > 600
        render json: {error: 'The requested range is not acceptable', message: "Maximum range is 600 seconds, you requested #{params[:end_offset].to_i - params[:start_offset].to_i} seconds between start_offset=#{params[:start_offset]} and end_offset=#{params[:end_offset]}"}.to_json, status: :requested_range_not_satisfiable
      end
    end

    if !(params[:start_offset]=~OFFSET_REGEXP)
      render json: {error: 'start_offset parameter must be a float number indicating seconds (maximum precision milliseconds, e.g., 1.234)'}.to_json, status: :unprocessable_entity
    elsif !(params[:end_offset]=~OFFSET_REGEXP)
      render json: {error: 'end_offset parameter must be a float number indicating seconds (maximum precision milliseconds, e.g., 1.234)'}.to_json, status: :unprocessable_entity
    elsif params[:end_offset].to_i > @audio_recording.duration_seconds
      render json: {error: "end_offset parameter must be a smaller than the duration of the audio recording requested: #{@audio_recording.duration_seconds} seconds"}.to_json, status: :requested_range_not_satisfiable
    elsif params[:start_offset].to_i >= @audio_recording.duration_seconds
      render json: {error: "start_offset parameter must be a smaller than the duration of the audio recording requested: #{@audio_recording.duration_seconds} seconds"}.to_json, status: :requested_range_not_satisfiable
    elsif params[:start_offset].to_i >= params[:end_offset].to_i
      render json: {error: "start_offset parameter must be a smaller than end_offset"}.to_json, status: :requested_range_not_satisfiable
    end
  end

  def log_options(options, description)
    logger.warn "mediaController - Provided parameters at #{description}: #{options}"
  end
end