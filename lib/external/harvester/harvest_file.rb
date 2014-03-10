module Harvester
  class File

    attr_reader :audio_file

    def initialize(audio_file, harvester_shared)
      @audio_file = audio_file
      @shared = harvester_shared
    end

    # calculate the audio recording start date and time
    def get_file_info_from_name(utc_offset = nil)
      if ::File.exists? @audio_file

        #access_time = File.atime full_path
        #change_time = File.ctime full_path

        result = {
            recording_start: ::File.mtime(@audio_file),
            file_name: ::File.basename(@audio_file),
            extension: ::File.extname(@audio_file).reverse.chomp('.').reverse
        }

        # Without project, site, uploader, and utc offset
        @audio_file.scan(/^(.+)_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.([^.]*)$/) do |prefix, year, month, day, hour, min, sec, extension|
          result[:recording_start] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset)
          result[:prefix] = prefix
          result[:extension] = extension
        end

        # With project, site, uploader, and Z for utc offset (=UTC/GMT)
        @audio_file.scan(/^p(\d+)_s(\d+)_u(\d+)_d(\d{4})(\d{2})(\d{2})_t(\d{2})(\d{2})(\d{2})Z\.([^.]*)$/) do |project_id, site_id, uploader_id, year, month, day, hour, min, sec, extension|
          result[:recording_start] = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, '+0')
          result[:extension] = extension
          result[:project_id] = project_id.to_i
          result[:site_id] = site_id.to_i
          result[:uploader_id] = uploader_id.to_i
        end

        if result[:recording_start].nil?
          msg = "Could not get recording start info for '#@audio_file'."
          @shared.log_with_puts Logger::ERROR, msg
          raise Exceptions::HarvesterError, msg
        else
          @shared.log_with_puts Logger::DEBUG, "Recording start info for '#@audio_file': '#{result}'"
          result
        end
      else
        msg = "Could not find audio file '#@audio_file'."
        @shared.log_with_puts Logger::ERROR, msg
        raise Exceptions::HarvesterIOError, msg
      end
    end

    # return a hash[:file_to_process] = file_info
    def get_file_info_hash(full_path)
      if File.exists? full_path
        file_info = @media_cacher.audio.info(full_path)
        if file_info.nil? || file_info.empty?
          @shared.log_with_puts Logger::ERROR, "Could not get file info for '#{full_path}': '#{file_info}'"
          nil
        else
          @shared.log_with_puts Logger::DEBUG, "File info '#{full_path}': '#{file_info}'"
          file_info
        end
      end
    end

    def record_file_moved(create_result_params)
      if @auth_token
        new_params = {
            :auth_token => @auth_token,
            :audio_recording => {
                :file_hash => create_result_params['file_hash'],
                :uuid => create_result_params['uuid']
            }
        }
        endpoint = @settings.endpoint_update_status.gsub(':id', create_result_params['id'].to_s)
        response = send_request('Record audio recording file moved', :put, endpoint, new_params)
        if response.code == '200' || response.code == '204'
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

  end
end