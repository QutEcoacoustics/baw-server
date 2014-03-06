module Harvester
  class File

    attr_reader :file

    def initialize(file, harvester_shared)



      @file = file
      @shared = harvester_shared
    end

    # calculate the audio recording start date and time
    def recording_start_datetime(full_path, utc_offset)
      if File.exists? full_path
        #access_time = File.atime full_path
        #change_time = File.ctime full_path
        modified_time = File.mtime full_path

        file_name = File.basename full_path

        datetime_from_file = modified_time

        # _yyyyMMdd_HHmmss.
        file_name.scan(/.*_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\..+/) do |year, month, day, hour, min, sec|
          datetime_from_file = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset)
        end

        # _yyMMdd-HHmm.
        file_name.scan(/.*_(\d{2})(\d{2})(\d{2})-(\d{2})(\d{2})\..+/) do |year, month, day, hour, min|
          datetime_from_file = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, 0, utc_offset)
        end

        datetime_from_file
      else
        nil
      end
    end

    # return a hash[:file_to_process] = file_info
    def get_file_info_hash(files_to_process)
      file_info_hash = Hash.new
      unless files_to_process.nil?
        files_to_process.each do |file_to_process|
          # get info about the file to process
          file_info = @media_cacher.audio.info(file_to_process)

          if audio_info?(file_info)
            file_info_hash[file_to_process] = file_info
            log Logger::DEBUG, "File info '#{file_to_process}': '#{file_info}'"
          else
            nil
            # raise exception if audio info could not be retrieved
            raise Exceptions::HarvesterAnalysisError, "Could not get file info for '#{file_to_process}': '#{file_info}'"
          end
        end
      end
      file_info_hash
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