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

module Harvester
  class Shared

    attr_reader :global_config, :global_config_file,
    attr_accessor :auth_token

    # @param [string] global_config_file
    def initialize(global_config_file)
      @global_config_file =  global_config_file
      @global_config = load_config_file(@global_config_file)
      @listen_path = yaml['settings']['paths']['harvester_to_do']
      # this sets the logger which is used in the harvester and shared Audio tools (audioffmpeg, audiosox, etc.)
      Logging::set_logger(Logger.new("#{@listen_path}/listen.log"))
    end


    # @param [string] description
    # @param [Symbol] method
    # @param [string] endpoint
    # @param [Hash] body
    # @return [Net::HTTP::Response]
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
      request['Authorization'] = "Token token=\"#{@auth_token}\"" if @auth_token
      request.body = body.to_json unless body.blank?

      log Logger::DEBUG, "Sent request for '#{description}': #{request.inspect}, URL: #{@settings.host}:#{@settings.port}#{endpoint}, Body: #{request.body}"

      response = nil

      res = Net::HTTP.start(@settings.host, @settings.port) do |http|
        response = http.request(request)
      end


      log Logger::DEBUG, "Received response for '#{description}': #{response.inspect}, Body: #{response.body}"

      response
    end

    def load_config_file(file)
      YAML.load_file(file)
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