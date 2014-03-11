require 'yaml'
require 'logger'
require 'digest'
require 'net/http'
require 'json'
require 'fileutils'
require 'settingslogic'
require 'active_support/all'

require File.dirname(__FILE__) + '/../../modules/logging'
require File.dirname(__FILE__) + '/../../modules/audio_base'
require File.dirname(__FILE__) + '/../../modules/exceptions'
require File.dirname(__FILE__) + '/../../modules/cache_base'
require File.dirname(__FILE__) + '/../../modules/media_cacher'

# used when running outside rails
class Settings < Settingslogic
  namespace 'settings'
end

module Harvester

  # required for running tests under rails
  class Settings < Settingslogic
    namespace 'settings'
  end

  class Harvester
=begin
This class is the audio file harvester. There are 3 files that make up the harvester:
this file, harvester_single_file.rb and harvester_communication.rb

=end
    def initialize(yaml_settings_file, dir_to_process)

      raise Exceptions::HarvesterConfigFileNotFound, "Configuration file not found: #{yaml_settings_file}" unless File.exists?(yaml_settings_file)
      raise Exceptions::HarvesterConfigurationError, "Directory to process not found: #{dir_to_process}" unless Dir.exists?(dir_to_process)

      # both files will be created only when the first log becomes necessary
      # see def log
      @error_log_file = "#{dir_to_process}/error.log"
      @process_log_file = "#{dir_to_process}/process.log"
      @listen_log_file = "#{dir_to_process}/listen.log"

      begin
        # for running outside of rails
        ::Settings.source(yaml_settings_file)
        Harvester::Settings.source(yaml_settings_file)

        # when running in tests.
        @settings = Settings.new(yaml_settings_file)

        @config_file_object = nil
        @dir_to_process = dir_to_process
        @media_cacher = MediaCacher.new(@settings.paths.temp_files)

      rescue Exceptions::HarvesterError => e
        log Logger::ERROR, "Error Initializing harvester. Check settings in #{yaml_settings_file}: #{e.message}"
        log Logger::DEBUG, e
        raise e
      end

    end


    def start_harvesting

      log_with_puts Logger::INFO, 'Started harvesting.'

      begin

        # get login token
        @auth_token = request_login

        # check if absolute_path has required files and the right format
        check_config_file(@dir_to_process)

        # replace ids in endpoint paths
        replace_endpoint_ids

        # check settings against endpoint
        check_config_against_endpoint

        harvest_dir(@dir_to_process)

      rescue Exceptions::HarvesterError, Errno::ENOENT, Exception => e
        log_with_puts Logger::ERROR, "Error Processing #{@dir_to_process}:\n\t#{e.message}"
        log Logger::DEBUG, e
        raise
      end

    end

    private

    def replace_endpoint_ids
      project_id = @config_file_object['project_id']
      site_id = @config_file_object['site_id']
      uploader_id = @config_file_object['uploader_id']
      @settings.endpoint_create
      .gsub!(':project_id', project_id.to_s)
      .gsub!(':site_id', site_id.to_s)
      @settings.endpoint_check_uploader
      .gsub!(':project_id', project_id.to_s)
      .gsub!(':site_id', site_id.to_s)
      .gsub!(':uploader_id', uploader_id.to_s)
    end

    ##########################################
    # File system helpers
    ##########################################

    def check_config_file(full_directory_path)

      full_file_path = File.join(full_directory_path, @settings.config_file_name)

      # if the config file does not exist, raise exception
      if File.exists?(full_file_path)
        # load the config file
        @config_file_object = YAML.load_file(full_file_path)

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
      else
        # load the config file in the same dir, raise exception if it doesn't exits
        false
        raise Exceptions::HarvesterConfigFileNotFound.new("Config file #{full_file_path} does not exist.")
      end
    end

    def audio_info?(file_info)
      !file_info.empty?
    end


    # get the list of files in a directory, excluding the config file.
    def file_list(full_directory_path)
      path = File.join(full_directory_path, '*')
      list_of_files = Dir[path].reject { |fn| File.directory?(fn) || File.basename(fn) == @settings.config_file_name || File.basename(fn) == File.basename(@process_log_file) || File.basename(fn) == File.basename(@error_log_file) || File.basename(fn) == File.basename(@listen_log_file) }
      if list_of_files.empty?
        log Logger::WARN, "Could not find any audio files in #{full_directory_path}"
      else
        log Logger::INFO, "Found #{list_of_files.size} files in #{full_directory_path}"
        list_of_files
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
    # Metadata helpers
    ##########################################

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

    def generate_hash(file_path)
      incr_hash = Digest::SHA256.new

      File.open(file_path) do |file|
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
      if @auth_token

        check_uploader_response = send_request('Check uploader id', :get, @settings.endpoint_check_uploader, nil)
        if check_uploader_response.code.to_s == '204'
          log_with_puts Logger::INFO, "Uploader with id #{@config_file_object['uploader_id']} has project access."
          true
        else
          false
          raise Exceptions::HarvesterConfigurationError, "Check your #{@settings.config_file_name} file: Uploader ID #{@config_file_object['uploader_id']} does not have required permissions for Project ID #{@config_file_object['project_id']}"
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
              :original_file_name => File.basename(file_path)
          }}

      to_send[:audio_recording].merge!(file_info)

      to_send
    end

    def send_request(description, method, endpoint, body)
      if method == :get
        request = Net::HTTP::Get.new(endpoint)

      elsif method == :put
        request = Net::HTTP::Put.new(endpoint)
      elsif method == :post
        request = Net::HTTP::Post.new(endpoint)
      else
        raise HarvesterError, "Unrecognised HTTP method #{method}."
      end
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      if @auth_token
        request['Authorization'] = "Token token=\"#{@auth_token}\""
      end
      request.body = body.to_json unless body.nil?

      log Logger::DEBUG, "Sent request for '#{description}': '#{request.inspect}', URL: '#{@settings.host}:#{@settings.port}#{endpoint}', Body: '#{request.body}'"

      response = nil

      begin
        res = Net::HTTP.start(@settings.host, @settings.port) do |http|
          response = http.request(request)
        end
      rescue StandardError => e
        log Logger::ERROR, "Error requesting URL '#{@settings.host}:#{@settings.port}#{endpoint}': #{e}"
        raise e
      end

      log Logger::DEBUG, "Received response for '#{description}': '#{response.inspect}', Body: '#{response.body}'"

      response
    end

    # request an auth token
    def request_login

      login_response = send_request('Login', :post, @settings.endpoint_login, {email: @settings.login_email, password: @settings.login_password})

      if login_response.code == '200' && !login_response.body.blank?
        log_with_puts Logger::INFO, 'Successfully logged in.'
        json_resp = JSON.parse(login_response.body)
        json_resp['auth_token']
      else
        log Logger::ERROR, 'Failed to log in and obtain auth_token'
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
        raise Exceptions::HarvesterAnalysisError, "Request to create audio recording failed: code #{response.code}, Message: #{response.message}, Body: #{response.body}"
      end
    end


    ##########################################
    # RESTful API to update AudioRecording
    ##########################################

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
        log Logger::ERROR, "Login problem."
        false
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

        ################################
        # Create audiorecording
        ################################
        post_result = create_new_audiorecording(to_send, file_to_process)

        # if the creation of audio recording was successful, move file and update status
        unless post_result.nil?
          response_json = JSON.parse(post_result.body)
          recorded_date = DateTime.parse(response_json['recorded_date'])

          file_name_params = {
              :uuid => response_json['uuid'],
              :recorded_date => recorded_date,
              :original_format => File.extname(file_to_process)
          }

          log Logger::DEBUG, "Parameters for moving file: '#{file_name_params}'."
          file_name = @media_cacher.cache.original_audio.file_name(
              file_name_params[:uuid],
              file_name_params[:recorded_date],
              file_name_params[:recorded_date],
              file_name_params[:original_format])
          source_possible_paths = @media_cacher.cache.possible_storage_paths(@media_cacher.cache.original_audio, file_name)
          result_of_move = copy_file(file_to_process, source_possible_paths)
          log Logger::DEBUG, "File move results: #{result_of_move.to_json}"

          ################################
          # Record file move
          ################################
          if record_file_moved(response_json)
            log_with_puts Logger::INFO, "Successfully completed file: #{file_to_process}"
          else
            all_status_changed = false
          end
        end
      end

      if all_status_changed
        # move audio files, leave harvest.yml and log files.
        # can't move log files, they're still open and being used.
        target_dir = FileUtils.mkpath(File.join(@settings.paths.harvester_completed, File.basename(absolute_path)))
        files_to_move = file_list(absolute_path)
        files_to_move.each do |file_to_move|
          FileUtils.mv(file_to_move, File.join(target_dir, File.basename(file_to_move)))
        end
        log_with_puts Logger::INFO, "Successfully completed directory: #{absolute_path}"
      end
    end

    def log_with_puts(log_level, message)
      puts message
      log log_level, message
    end

    def log(log_level, message)
      # create log files if they haven't been created yet
      unless @log
        @log =Logger.new(@process_log_file)
        @log.formatter = Logger::Formatter.new
      end

      @log.add(log_level, message)
      Logging.logger.add(log_level, message)
      if log_level == Logger::FATAL || log_level == Logger::ERROR

        unless @error_log
          @error_log = Logger.new(@error_log_file)
          @error_log.formatter = Logger::Formatter.new
        end

        @error_log.add(log_level, message)
      end
    end
  end
end