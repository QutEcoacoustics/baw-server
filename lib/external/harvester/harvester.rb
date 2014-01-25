require 'yaml'
require 'logger'
require 'digest'
require 'net/http'
require 'json'
require 'fileutils'


require File.dirname(__FILE__) + '/../../modules/logging'
require File.dirname(__FILE__) + '/../../modules/audio_base'
require File.dirname(__FILE__) + '/../../modules/exceptions'
require File.dirname(__FILE__) + '/../../modules/cache'

module Harvester
  class Harvester

    def initialize(yaml_settings_file, dir_to_process)

      # both files will be created only when the first log becomes necessary
      # see def log
      @error_log_file = "#{dir_to_process}/error.log"
      @process_log_file = "#{dir_to_process}/process.log"
      @listen_log_file = "#{dir_to_process}/listen.log"

      begin
        yaml = YAML.load_file(yaml_settings_file)
        @host = yaml['host']
        @port = yaml['port']
        @config_file_name = yaml['config_file_name']
        @login_email = yaml['login_email']
        @login_password = yaml['login_password']
        @endpoint_create = yaml['endpoint_create']
        @endpoint_check_uploader = yaml['endpoint_check_uploader']
        @endpoint_record_move = yaml['endpoint_record_move']
        @endpoint_login = yaml['endpoint_login']

        @original_audio_paths = yaml['original_audios']
        @harvester_completed_path = yaml['harvester_completed_path']

        @logger_file = yaml['harvester_log_file']

        @config_file_object = nil
        @dir_to_process = dir_to_process

        Net::HTTP.start(@host, @port) do |http|
          @auth_token = request_login(http)
        end

      rescue Exceptions::HarvesterError => e
        log Logger::ERROR, "Error Initializing harvester. Check settings in #{yaml_settings_file}: #{e.message}"
        log Logger::DEBUG, e
        raise e
      end

    end


    def start_harvesting

      begin
        # check if absolute_path has required files and the right format
        check_config_file(@dir_to_process)

        # replace ids in endpoint paths
        replace_endpoint_ids

        # check settings against endpoint
        check_config_against_endpoint()

        harvest_dir(@dir_to_process)

      rescue Exceptions::HarvesterError => e
        log Logger::ERROR,  "Error Processing #{@dir_to_process}:\n#{e.message}"
        log Logger::DEBUG,  e
        raise e
      end

    end

    private

    def replace_endpoint_ids
      project_id = @config_file_object['project_id']
      site_id = @config_file_object['site_id']
      @endpoint_create.gsub!(':project_id', project_id.to_s).gsub!(':site_id', site_id.to_s)
      @endpoint_check_uploader.gsub!(':project_id', project_id.to_s).gsub!(':site_id', site_id.to_s)
    end

    ##########################################
    # File system helpers
    ##########################################

    def check_config_file(full_directory_path)

      # if the config file does not exist, raise exception
      if !File.exists?("#{full_directory_path}/#{@config_file_name}")
        # load the config file in the same dir, raise exception if it doesn't exits
        false
        raise Exceptions::HarvesterConfigFileNotFound.new("Config file #{full_directory_path}/#{@config_file_name} does not exist.")
      else
        # load the config file
        @config_file_object = YAML.load_file("#{full_directory_path}/#{@config_file_name}")

        # get project_id and site_id from config file, raise exception if they are not defined
        project_id = @config_file_object['project_id']
        site_id = @config_file_object['site_id']

        if project_id.nil? || !project_id.is_a?(Fixnum)
          false
          raise Exceptions::HarvesterConfigurationError, 'Config file must contain a project_id'
        elsif site_id.nil? || !site_id.is_a?(Fixnum)
          false
          raise Exceptions::HarvesterConfigurationError, 'Config file must contain a site_id'
        end

        true
      end
    end

    def audio_info?(file_info)
      !file_info[:info][:ffmpeg].empty?
    end


    # get the list of files in a directory, excluding the config file.
    def file_list(full_directory_path)
      puts "file_list #{full_directory_path}"
      path = File.join(full_directory_path, '*')
      list_of_files = Dir[path].reject { |fn| File.directory?(fn) || File.basename(fn) == @config_file_name || File.basename(fn) == File.basename(@process_log_file) || File.basename(fn) == File.basename(@error_log_file) || File.basename(fn) == File.basename(@listen_log_file)}
      if list_of_files.empty?
        log Logger::DEBUG,  "Could not find any audio files in #{full_directory_path}"
      else
        list_of_files
      end
    end


    # copies the file after the AudioRecording has been created
    def copy_file(source_path,full_move_paths)
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
              log Logger::DEBUG, "Copied '#{source_path}' to '#{path}'."
              success.push({:source => source_path, :dest => path})
            rescue Exception => e
              log Logger::ERROR, "Error copying '#{source_path}' to '#{path}'. Exception: #{e}."
              fail.push({:source => source_path, :dest => path, :exception => e})
            end
          end
        end

        { :success => success, :fail => fail }
      end
    end

    ##########################################
    # Metadata helpers
    ##########################################

    # return a hash[:file_to_process] = file_info
    def get_file_info_hash(files_to_process)
      puts "get_file_info_hash #{files_to_process}"
      file_info_hash = Hash.new

      files_to_process.each do |file_to_process|
        # get info about the file to process
        file_info = Audio::info(file_to_process)

        if audio_info?(file_info)
          file_info_hash[file_to_process] = file_info
          log Logger::DEBUG,  "File info '#{file_to_process}': '#{file_info}'"
        else
          nil
          # raise exception if audio info could not be retrieved
          raise Exceptions::HarvesterAnalysisError, "Could not get file info for '#{file_to_process}': '#{file_info}'"
        end
      end
      file_info_hash
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
        file_name.scan(/.*_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\..+/) do |year, month, day, hour, min ,sec|
          datetime_from_file = DateTime.new(year.to_i, month.to_i, day.to_i, hour.to_i, min.to_i, sec.to_i, utc_offset)
        end
        datetime_from_file
      else
        nil
      end
    end

    def generate_hash(file_path)
      incr_hash = Digest::SHA256.new

      File.open(file_path) do|file|
        buffer = ''

        # Read the file 512 bytes at a time
        until file.eof
          file.read(512, buffer)
          incr_hash.update(buffer)
        end
      end

      incr_hash
    end

    ##########################################
    # RESTful API helpers
    ##########################################

    def check_config_against_endpoint
      Net::HTTP.start(@host, @port) do |http|
        if @auth_token
          content = {:uploader_id => @config_file_object['uploader_id']}
          check_uploader_get = construct_request(:get, @endpoint_check_uploader, content)
          check_uploader_response = http.request(check_uploader_get)
          if check_uploader_response.code == '204'
            log Logger::DEBUG, 'Uploader ID has project access.'
            true
          else
            false
            raise Exceptions::HarvesterConfigurationError, "Check your #{@config_file_name} file: Uploader ID #{@config_file_object['uploader_id']} does not have required permissions for Project ID #{@config_file_object['project_id']}"
          end
        end
      end
    end

    def create_params(file_path, file_info, config_file_object)
      # info we need to send, construct based on mime type

      media_type = file_info[:media_type]
      recording_start = recording_start_datetime(file_path, config_file_object['utc_offset'])

      to_send = {
          :audio_recording => {
              :file_hash => 'SHA256::'+generate_hash(file_path).hexdigest,
              :uploader_id => config_file_object['uploader_id'],
              :recorded_date => recording_start,
              :original_file_name =>  File.basename(file_path)
          }}

      to_send[:audio_recording].merge!(file_info)

      to_send
    end

    def construct_request(method, endpoint, body)
      if method == :get
        request = Net::HTTP::Get.new(endpoint)

      elsif method == :put
        request = Net::HTTP::Put.new(endpoint)
      else
        request = Net::HTTP::Post.new(endpoint)
      end
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      if @auth_token
        request['Authorization'] = "Token token=\"#{@auth_token}\""
      end
      request.body = body.to_json
      request
    end

    def construct_login_request()
      # set up the login HTTP post
      content = {:email => @login_email, :password => @login_password}
      login_post = construct_request(:post, @endpoint_login, content)
      log Logger::DEBUG,  "Login request: #{login_post.inspect}, Body: #{login_post.body}"
      login_post
    end

    # request an auth token
    def request_login(http)
      login_post = construct_login_request
      login_response = http.request(login_post)
      log Logger::DEBUG,  "Login response: #{login_response.code}, Message: #{login_response.message}, Body: #{login_response.body}"

      if login_response.code == '200'
        puts 'Successfully logged in'
        log Logger::DEBUG, 'Successfully logged in.'

        json_resp = JSON.parse(login_response.body)
        json_resp['auth_token']
      else
        log Logger::ERROR,'Failed to log in and obtain auth_token'
        raise Exceptions::HarvesterConfigurationError, 'Failed to log in and obtain auth_token'
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
    def create_new_audiorecording(post_params)
      Net::HTTP.start(@host, @port) do |http|
          create_post = construct_request(:post, @endpoint_create,post_params.clone)
          log Logger::DEBUG,  "Create request: #{create_post.inspect}, Body: #{create_post.body}"

          response = http.request(create_post)
          log Logger::DEBUG,  "Create response: #{response.code}, Message: #{response.message}, Body: #{response.body}"

          if response.code == '201'
            response_json = JSON.parse(response.body)
            log Logger::INFO,  'New audio recording created.'
            response
          else
            raise Exceptions::HarvesterAnalysisError, "Request to create audio recording failed: code #{response.code}, Message: #{response.message}, Body: #{response.body}"
          end
      end
    end


    ##########################################
    # RESTful API to update AudioRecording
    ##########################################

    def record_file_move(create_result_params)
      Net::HTTP.start(@host, @port) do |http|

        if @auth_token
          new_params = {
              :auth_token => @auth_token,
              :audio_recording => {
                  :file_hash => create_result_params['file_hash'],
                  :uuid => create_result_params['uuid']
              }
          }
          endpoint = @endpoint_record_move.gsub(':id',create_result_params['id'].to_s)
          create_post = construct_request(:put, endpoint, new_params)
          log Logger::DEBUG,  "Record move request: #{create_post.inspect}, Body: #{create_post.body}"

          response = http.request(create_post)
          log Logger::DEBUG, "Record move response: #{response.code}, Message: #{response.message}, Body: #{response.body}"

          if response.code == '200' || response.code == '204'
            true
          else
            log Logger::ERROR,  "Record move response was not recognised: code #{response.code}, Message: #{response.message}, Body: #{response.body}"
            false
          end
        else
          log Logger::ERROR, "Login response, expected 200 OK or 204, got #{response.code}, Message: #{response.message}, Body: #{response.body}"
          false
        end
      end
    end


    ##########################################
    # Main method
    ##########################################
    def harvest_dir(absolute_path)

      # get non-config files from the sub dir
      files_to_process = file_list(absolute_path)

      # try to get file info for all files to process, returns nil if only one of the files is unsuccessful
      file_info_hash = get_file_info_hash(files_to_process)

      all_status_changed = true # checks if all statuses changed
      # only continue posting audio recordings to endpoint if we were able to get fileinfos for all files to process
      file_info_hash.each do |file_to_process, file_info|

          # get the params to send
          to_send = create_params(file_to_process, file_info, @config_file_object)
          log Logger::DEBUG, "Posting file info for '#{file_to_process}', params to send '#{to_send}'"

          ################################
          # Create audiorecording
          ################################
          post_result = create_new_audiorecording(to_send)

          # if the creation of audio recording was successful, move file and update status
          unless post_result.nil?
            log Logger::DEBUG,   "Successfully posted file info: '#{post_result.inspect}'"

            response_json = JSON.parse(post_result.body)
            recorded_date = DateTime.parse(response_json['recorded_date'])

            file_name_params = {
                :uuid => response_json['uuid'],
                :date => recorded_date.strftime("%Y%m%d"),
                :time => recorded_date.strftime("%H%M%S"),
                :original_format => File.extname(file_to_process)
            }

            log Logger::DEBUG, "Parameters for moving file: '#{file_name_params}'."
            cache = CacheBase.from_paths_orig(@original_audio_paths)
            file_name = cache.original_audio_file(file_name_params)
            source_possible_paths = cache.possible_original_audio_paths(file_name)
            result_of_move = copy_file(file_to_process, source_possible_paths)
            log Logger::DEBUG, "File move results: #{result_of_move.to_json}"

            ################################
            # Record file move
            ################################
            if record_file_move(response_json)
              log Logger::INFO, "Successfully completed file: #{file_to_process}"
            else
              all_status_changed = false
            end
          end
      end

      if all_status_changed
        FileUtils.mv(absolute_path, @harvester_completed_path[0])
        log Logger::INFO, "Successfully completed directory: #{absolute_path}"
      end
    end



    def log(log_level, message)
      # create log files if they haven't been created yet
      @LOG = @LOG || Logger.new(@process_log_file, 5, 300.megabytes)
      @LOG.add(log_level, message)
      Logging.logger.add(log_level, message)
      if log_level == Logger::FATAL ||  log_level == Logger::ERROR
        @ERROR_LOG = @ERROR_LOG ||Logger.new(@error_log_file, 5, 300.megabytes)
        @ERROR_LOG.add(log_level, message)
      end
    end
  end
end