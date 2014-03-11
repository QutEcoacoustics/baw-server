module Harvester
  class AudioFile

    attr_reader :shared

    # Initialize Harvester::File
    # @param [Harvester::Shared] harvester_shared
    def initialize(harvester_shared)
      @shared = harvester_shared
    end

    def start_harvesting_file(full_path, uploader_id, utc_offset = nil)

      # collect info about audio file
      file_info_name = info_from_name(full_path, utc_offset)
      file_info_content = info_from_content(full_path)
      file_hash = generate_hash(file_path)
      file_hash_formatted = 'SHA256::'+file_hash.hexdigest
      recording_start = ''
      original_file_name = File.basename(file_path)

      {
          audio_recording: {
              file_hash: file_hash_formatted,
              uploader_id: uploader_id,
              recorded_date: recording_start,
              original_file_name: original_file_name
          }
      }

      # make request to create new (or reuse existing) audio recording
      create_new_audiorecording()
    end

    private

    # calculate the audio recording start date and time.
    # @return [Hash] Parsed info from file name
    # @param [string] audio_file
    # @param [string] utc_offset optional offset from UTC
    def info_from_name(audio_file, utc_offset = nil)
      if ::File.exists? audio_file

        #access_time = File.atime full_path
        #change_time = File.ctime full_path

        modified_time = ::File.mtime(audio_file)
        file_name = ::File.basename(audio_file)
        extension = ::File.extname(audio_file).reverse.chomp('.').reverse

        result = {
            recording_start: nil,
            file_modified: modified_time,
            file_name: file_name,
            extension: extension
        }

        additional_info = parse_all_info_filename(file_name)

        if additional_info.empty?
          additional_info = parse_datetime_offset_filename(file_name)
        end

        if additional_info.empty?
          additional_info = parse_datetime_filename(file_name, utc_offset)
        end

        if additional_info.empty?
          msg = "Could not get recording start info for '#{audio_file}'."
          @shared.log_with_puts Logger::ERROR, msg
          raise Exceptions::HarvesterError, msg
        else
          @shared.log Logger::DEBUG, "Recording start info for '#{audio_file}': '#{result}'"
          result.merge(additional_info)
        end

      else
        msg = "Could not find audio file '#{audio_file}'."
        @shared.log_with_puts Logger::ERROR, msg
        raise Exceptions::HarvesterIOError, msg
      end
    end

    # Get info about file from contents.
    # @param [string] full_path
    # @return [Hash] info from file contents
    def info_from_content(full_path)
      if ::File.exists? full_path
        file_info = @shared.media_cacher.audio.info(full_path)
        if file_info.nil? || file_info.empty?
          @shared.log_with_puts Logger::ERROR, "Could not get file info for '#{full_path}': '#{file_info}'"
          nil
        else
          @shared.log Logger::DEBUG, "File info '#{full_path}': '#{file_info}'"
          file_info
        end
      end
    end

    def record_file_moved(audio_recording_info)
      if @shared.auth_token
        new_params = {
            auth_token: @shared.auth_token,
            audio_recording: {
                file_hash: audio_recording_info['file_hash'],
                uuid: audio_recording_info['uuid']
            }
        }
        endpoint = @shared.endpoints.update_status.gsub(':id', audio_recording_info['id'].to_s)
        response = @shared.send_request('Record audio recording file moved', :put, endpoint, new_params)
        if response.code == '200' || response.code == '204'
          @shared.log Logger::DEBUG, "File move recorded '#{full_path}': '#{file_info}'"
          true
        else
          log Logger::ERROR, "Record move response was not recognised: code #{response.code}, Message: #{response.message}, Body: #{response.body}"
          false
        end
      else
        log Logger::ERROR, 'Login problem.'
        false
      end
    end

    # copies the file after the AudioRecording has been created
    def copy_file(source_path, full_move_paths)
      unless source_path.nil? || full_move_paths.size < 1
        success = []
        fail = []

        full_move_paths.each do |path|
          if File.exists?(path)
            log Logger::DEBUG, "File already exists, did not copy '#{source_path}' to '#{path}'."
          else
            begin
              FileUtils.makedirs(File.dirname(path))
              FileUtils.copy(source_path, path)
              success.push({:source => source_path, :dest => path})
            rescue Exception => e
              fail.push({:source => source_path, :dest => path, :exception => e})
            end
          end
        end

        {:success => success, :fail => fail}
      end
    end

    ##########################################
    # RESTful API to create AudioRecording
    ##########################################

    # get uuid for audio recording from website via REST API
    # If you post to a Ruby on Rails REST API endpoint, then you'll get an
    # InvalidAuthenticityToken exception unless you set a different
    # content type in the request headers, since any post from a form must
    # contain an authenticity token.
    def create_new_audiorecording(post_params, file_to_process)
      # change sample_rate to sample_rate_hertz
      request_body = post_params.clone
      request_body[:audio_recording][:sample_rate_hertz] = request_body[:audio_recording][:sample_rate].to_i
      request_body[:audio_recording].delete :sample_rate
      request_body[:audio_recording].delete :max_amplitude

      response = send_request('Create audiorecording', :post, @settings.endpoint_create, request_body)
      if response.code == '201'
        response_json = JSON.parse(response.body)
        log_with_puts Logger::INFO, "Created new audio recording with id #{response_json['id']}: #{file_to_process}."
        response
      else
        raise Exceptions::HarvesterEndpointError, "Request to create audio recording failed: code #{response.code}, Message: #{response.message}, Body: #{response.body}"
      end
    end

    def generate_hash(file_path)
      incr_hash = Digest::SHA256.new

      ::File.open(file_path) do |file|
        buffer = ''

        # Read the file 512 bytes at a time
        until file.eof
          file.read(512, buffer)
          incr_hash.update(buffer)
        end
      end

      incr_hash
    end

    private

    def parse_all_info_filename(file_name)
      result = {}
      file_name.scan(/^p(\d+)_s(\d+)_u(\d+)_d(\d{4})(\d{2})(\d{2})_t(\d{2})(\d{2})(\d{2})Z\.([^.]*)$/) do |project_id, site_id, uploader_id, year, month, day, hour, min, sec, extension|
        result[:recording_start] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, '+0')
        result[:extension] = extension
        result[:project_id] = project_id.to_i
        result[:site_id] = site_id.to_i
        result[:uploader_id] = uploader_id.to_i
      end
      result
    end

    def parse_datetime_filename(file_name, utc_offset)
      result = {}
      file_name.scan(/^(.+)_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.([^.]*)$/) do |prefix, year, month, day, hour, min, sec, extension|
        result[:recording_start] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset)
        result[:prefix] = prefix
        result[:extension] = extension
      end
      result
    end

    def parse_datetime_offset_filename(file_name)
      result = {}
      file_name.scan(/^(.+)_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})([+-]\d{2})\.([^.]*)$/) do |prefix, year, month, day, hour, min, sec, offset, extension|
        result[:recording_start] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, offset.to_s)
        result[:prefix] = prefix
        result[:extension] = extension
      end
      result
    end

  end
end