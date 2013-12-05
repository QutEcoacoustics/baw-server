require './lib/modules/mime'
require './lib/modules/media_cacher'

class MediaController < ApplicationController
  include MediaCacher, Mime

  #load_resource :project, only: [:audio, :spectrogram]
  #load_resource :site, only: [:audio, :spectrogram]
  load_and_authorize_resource :audio_recording, only: [:show]

  before_filter :check_offset_format

  AUDIO_MEDIA_TYPES = [Mime::Type.lookup('audio/webm'), Mime::Type.lookup('audio/webma'),
                       Mime::Type.lookup('audio/ogg'), Mime::Type.lookup('audio/oga'),
                       Mime::Type.lookup('audio/mp3'), Mime::Type.lookup('audio/mpeg'),
                       Mime::Type.lookup('audio/wav')] #Mime::Type.lookup('audio/x-wav')
  IMAGE_MEDIA_TYPES = [Mime::Type.lookup('image/png')]

  OFFSET_REGEXP = /^\d+(\.\d{1,3})?$/ # passes '111', '11.123'

  def show
    if @audio_recording.status != 'ready'
      render json: {error: 'Audio recording is not ready'}.to_json, status: :unprocessable_entity
    else
      if %w(json mp3 webm ogg png).include?(params[:format].downcase)
        options = Hash.new
        options[:datetime] = @audio_recording.recorded_date
        options[:original_format] = File.extname(@audio_recording.original_file_name) unless @audio_recording.original_file_name.blank?
        options[:original_format] = '.' + Mime::Type.lookup(@audio_recording.media_type).to_sym.to_s if options[:original_format].blank?
        options[:format] = params[:format]
        options[:start_offset] = (params[:start_offset] || 0).to_f
        options[:end_offset] = (params[:end_offset] || @audio_recording.duration_seconds).to_f
        options[:uuid] = @audio_recording.uuid
        options[:id] = @audio_recording.id
        mime_type = Mime::Type.lookup_by_extension(options[:format])

        download_options = {
            media_type: mime_type,
            site_name: @audio_recording.site.name,
            recorded_date: @audio_recording.recorded_date,
            ext: options[:format]
        }

        if AUDIO_MEDIA_TYPES.include?(mime_type)
          options[:channel] = (params[:channel] || Settings.cached_audio_defaults[options[:format]].channel).to_i
          options[:sample_rate] = (params[:sample_rate] || Settings.cached_audio_defaults[options[:format]].sample_rate).to_f
          # date and time are for finding the original audio file
          options[:date] = @audio_recording.recorded_date.strftime "%y%m%d"
          options[:time] = @audio_recording.recorded_date.strftime "%H%M"
          download_options[:file_path] = MediaCacher::create_audio_segment(options)
          download_file(download_options)
        elsif  IMAGE_MEDIA_TYPES.include?(mime_type)
          options[:channel] = (params[:channel] || Settings.cached_spectrogram_defaults[options[:format]].channel).to_i
          options[:sample_rate] = (params[:sample_rate] || Settings.cached_spectrogram_defaults[options[:format]].sample_rate).to_f
          options[:window] = (params[:window] || Settings.cached_spectrogram_defaults[options[:format]].window).to_i
          options[:colour] = (params[:colour] || Settings.cached_spectrogram_defaults[options[:format]].colour).to_s
          options[:date] = @audio_recording.recorded_date.strftime "%y%m%d"
          options[:time] = @audio_recording.recorded_date.strftime "%H%M"
          full_path = MediaCacher::generate_spectrogram(options)
          #download_file(full_path, mime_type)
          send_file full_path, :stream => true, :buffer_size => 4096, :disposition => 'inline', :type => mime_type, :content_type => mime_type
        else
          options[:available_audio_formats] = Settings.cached_audio_defaults.each { |key, value| value.merge!({mime_type: Mime::Type.lookup_by_extension(key).to_s, url: audio_recording_media_path(@audio_recording, format: key, start_offset: params[:start_offset], end_offset: params[:end_offset])}) }
          options[:available_image_formats] = Settings.cached_spectrogram_defaults.each { |key, value| value.merge!({mime_type: Mime::Type.lookup_by_extension(key).to_s, url: audio_recording_media_path(@audio_recording, format: key, start_offset: params[:start_offset], end_offset: params[:end_offset])}) }
          render json: options.to_json
        end
      else
        render json: {error: 'Requested format is invalid. It has to be mp3, webm, ogg, png or json'}.to_json, status: :unsupported_media_type
      end
    end
  end


  def reference_audio

  end

  def reference_spectrogram

  end

  private

  def download_file(options)
    #raise ArgumentError, 'File does not exist on disk' if full_path.blank?
    # are HEAD requests supported?
    # more info: http://patshaughnessy.net/2010/10/11/activerecord-with-large-result-sets-part-2-streaming-data
    # http://blog.sparqcode.com/2012/02/04/streaming-data-with-rails-3-1-or-3-2/
    # http://stackoverflow.com/questions/3507594/ruby-on-rails-3-streaming-data-through-rails-to-client
    # ended up using StringIO as a MemoryStream to store part of audio file requested.

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
end