=begin
#SFTPGo

#SFTPGo REST API

The version of the OpenAPI document: 2.0.0

Generated by: https://openapi-generator.tech
OpenAPI Generator version: 5.0.0-SNAPSHOT

=end

require 'cgi'

module SftpgoGeneratedClient
  class MaintenanceApi
    attr_accessor :api_client

    def initialize(api_client = ApiClient.default)
      @api_client = api_client
    end
    # Backup SFTPGo data serializing them as JSON
    # The backup is saved to a local file to avoid to expose users hashed passwords over the network. The output of dumpdata can be used as input for loaddata
    # @param output_file [String] Path for the file to write the JSON serialized data to. This path is relative to the configured \&quot;backups_path\&quot;. If this file already exists it will be overwritten
    # @param [Hash] opts the optional parameters
    # @option opts [Integer] :indent indent:   * &#x60;0&#x60; no indentation. This is the default   * &#x60;1&#x60; format the output JSON 
    # @return [ApiResponse]
    def dumpdata(output_file, opts = {})
      data, _status_code, _headers = dumpdata_with_http_info(output_file, opts)
      data
    end

    # Backup SFTPGo data serializing them as JSON
    # The backup is saved to a local file to avoid to expose users hashed passwords over the network. The output of dumpdata can be used as input for loaddata
    # @param output_file [String] Path for the file to write the JSON serialized data to. This path is relative to the configured \&quot;backups_path\&quot;. If this file already exists it will be overwritten
    # @param [Hash] opts the optional parameters
    # @option opts [Integer] :indent indent:   * &#x60;0&#x60; no indentation. This is the default   * &#x60;1&#x60; format the output JSON 
    # @return [Array<(ApiResponse, Integer, Hash)>] ApiResponse data, response status code and response headers
    def dumpdata_with_http_info(output_file, opts = {})
      if @api_client.config.debugging
        @api_client.config.logger.debug 'Calling API: MaintenanceApi.dumpdata ...'
      end
      # verify the required parameter 'output_file' is set
      if @api_client.config.client_side_validation && output_file.nil?
        fail ArgumentError, "Missing the required parameter 'output_file' when calling MaintenanceApi.dumpdata"
      end
      allowable_values = [0, 1]
      if @api_client.config.client_side_validation && opts[:'indent'] && !allowable_values.include?(opts[:'indent'])
        fail ArgumentError, "invalid value for \"indent\", must be one of #{allowable_values}"
      end
      # resource path
      local_var_path = '/dumpdata'

      # query parameters
      query_params = opts[:query_params] || {}
      query_params[:'output_file'] = output_file
      query_params[:'indent'] = opts[:'indent'] if !opts[:'indent'].nil?

      # header parameters
      header_params = opts[:header_params] || {}
      # HTTP header 'Accept' (if needed)
      header_params['Accept'] = @api_client.select_header_accept(['application/json'])

      # form parameters
      form_params = opts[:form_params] || {}

      # http body (model)
      post_body = opts[:body] 

      # return_type
      return_type = opts[:return_type] || 'ApiResponse' 

      # auth_names
      auth_names = opts[:auth_names] || ['BasicAuth']

      new_options = opts.merge(
        :header_params => header_params,
        :query_params => query_params,
        :form_params => form_params,
        :body => post_body,
        :auth_names => auth_names,
        :return_type => return_type
      )

      data, status_code, headers = @api_client.call_api(:GET, local_var_path, new_options)
      if @api_client.config.debugging
        @api_client.config.logger.debug "API called: MaintenanceApi#dumpdata\nData: #{data.inspect}\nStatus code: #{status_code}\nHeaders: #{headers}"
      end
      return data, status_code, headers
    end

    # Restore SFTPGo data from a JSON backup
    # Users and folders will be restored one by one and the restore is stopped if a user/folder cannot be added or updated, so it could happen a partial restore
    # @param input_file [String] Path for the file to read the JSON serialized data from. This can be an absolute path or a path relative to the configured \&quot;backups_path\&quot;. The max allowed file size is 10MB
    # @param [Hash] opts the optional parameters
    # @option opts [Integer] :scan_quota Quota scan:   * &#x60;0&#x60; no quota scan is done, the imported users will have used_quota_size and used_quota_files &#x3D; 0 or the existing values if they already exists. This is the default   * &#x60;1&#x60; scan quota   * &#x60;2&#x60; scan quota if the user has quota restrictions 
    # @option opts [Integer] :mode 
    # @return [ApiResponse]
    def loaddata(input_file, opts = {})
      data, _status_code, _headers = loaddata_with_http_info(input_file, opts)
      data
    end

    # Restore SFTPGo data from a JSON backup
    # Users and folders will be restored one by one and the restore is stopped if a user/folder cannot be added or updated, so it could happen a partial restore
    # @param input_file [String] Path for the file to read the JSON serialized data from. This can be an absolute path or a path relative to the configured \&quot;backups_path\&quot;. The max allowed file size is 10MB
    # @param [Hash] opts the optional parameters
    # @option opts [Integer] :scan_quota Quota scan:   * &#x60;0&#x60; no quota scan is done, the imported users will have used_quota_size and used_quota_files &#x3D; 0 or the existing values if they already exists. This is the default   * &#x60;1&#x60; scan quota   * &#x60;2&#x60; scan quota if the user has quota restrictions 
    # @option opts [Integer] :mode 
    # @return [Array<(ApiResponse, Integer, Hash)>] ApiResponse data, response status code and response headers
    def loaddata_with_http_info(input_file, opts = {})
      if @api_client.config.debugging
        @api_client.config.logger.debug 'Calling API: MaintenanceApi.loaddata ...'
      end
      # verify the required parameter 'input_file' is set
      if @api_client.config.client_side_validation && input_file.nil?
        fail ArgumentError, "Missing the required parameter 'input_file' when calling MaintenanceApi.loaddata"
      end
      allowable_values = [0, 1, 2]
      if @api_client.config.client_side_validation && opts[:'scan_quota'] && !allowable_values.include?(opts[:'scan_quota'])
        fail ArgumentError, "invalid value for \"scan_quota\", must be one of #{allowable_values}"
      end
      allowable_values = [0, 1, 2]
      if @api_client.config.client_side_validation && opts[:'mode'] && !allowable_values.include?(opts[:'mode'])
        fail ArgumentError, "invalid value for \"mode\", must be one of #{allowable_values}"
      end
      # resource path
      local_var_path = '/loaddata'

      # query parameters
      query_params = opts[:query_params] || {}
      query_params[:'input_file'] = input_file
      query_params[:'scan_quota'] = opts[:'scan_quota'] if !opts[:'scan_quota'].nil?
      query_params[:'mode'] = opts[:'mode'] if !opts[:'mode'].nil?

      # header parameters
      header_params = opts[:header_params] || {}
      # HTTP header 'Accept' (if needed)
      header_params['Accept'] = @api_client.select_header_accept(['application/json'])

      # form parameters
      form_params = opts[:form_params] || {}

      # http body (model)
      post_body = opts[:body] 

      # return_type
      return_type = opts[:return_type] || 'ApiResponse' 

      # auth_names
      auth_names = opts[:auth_names] || ['BasicAuth']

      new_options = opts.merge(
        :header_params => header_params,
        :query_params => query_params,
        :form_params => form_params,
        :body => post_body,
        :auth_names => auth_names,
        :return_type => return_type
      )

      data, status_code, headers = @api_client.call_api(:GET, local_var_path, new_options)
      if @api_client.config.debugging
        @api_client.config.logger.debug "API called: MaintenanceApi#loaddata\nData: #{data.inspect}\nStatus code: #{status_code}\nHeaders: #{headers}"
      end
      return data, status_code, headers
    end
  end
end