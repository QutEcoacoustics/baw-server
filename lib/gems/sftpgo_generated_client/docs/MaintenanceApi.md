# SftpgoGeneratedClient::MaintenanceApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**dumpdata**](MaintenanceApi.md#dumpdata) | **GET** /dumpdata | Backup SFTPGo data serializing them as JSON
[**loaddata**](MaintenanceApi.md#loaddata) | **GET** /loaddata | Restore SFTPGo data from a JSON backup



## dumpdata

> ApiResponse dumpdata(output_file, opts)

Backup SFTPGo data serializing them as JSON

The backup is saved to a local file to avoid to expose users hashed passwords over the network. The output of dumpdata can be used as input for loaddata

### Example

```ruby
# load the gem
require 'sftpgo_generated_client'
# setup authorization
SftpgoGeneratedClient.configure do |config|
  # Configure HTTP basic authorization: BasicAuth
  config.username = 'YOUR USERNAME'
  config.password = 'YOUR PASSWORD'
end

api_instance = SftpgoGeneratedClient::MaintenanceApi.new
output_file = 'output_file_example' # String | Path for the file to write the JSON serialized data to. This path is relative to the configured \"backups_path\". If this file already exists it will be overwritten
opts = {
  indent: 56 # Integer | indent:   * `0` no indentation. This is the default   * `1` format the output JSON 
}

begin
  #Backup SFTPGo data serializing them as JSON
  result = api_instance.dumpdata(output_file, opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling MaintenanceApi->dumpdata: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **output_file** | **String**| Path for the file to write the JSON serialized data to. This path is relative to the configured \&quot;backups_path\&quot;. If this file already exists it will be overwritten | 
 **indent** | **Integer**| indent:   * &#x60;0&#x60; no indentation. This is the default   * &#x60;1&#x60; format the output JSON  | [optional] 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## loaddata

> ApiResponse loaddata(input_file, opts)

Restore SFTPGo data from a JSON backup

Users and folders will be restored one by one and the restore is stopped if a user/folder cannot be added or updated, so it could happen a partial restore

### Example

```ruby
# load the gem
require 'sftpgo_generated_client'
# setup authorization
SftpgoGeneratedClient.configure do |config|
  # Configure HTTP basic authorization: BasicAuth
  config.username = 'YOUR USERNAME'
  config.password = 'YOUR PASSWORD'
end

api_instance = SftpgoGeneratedClient::MaintenanceApi.new
input_file = 'input_file_example' # String | Path for the file to read the JSON serialized data from. This can be an absolute path or a path relative to the configured \"backups_path\". The max allowed file size is 10MB
opts = {
  scan_quota: 56, # Integer | Quota scan:   * `0` no quota scan is done, the imported users will have used_quota_size and used_quota_files = 0 or the existing values if they already exists. This is the default   * `1` scan quota   * `2` scan quota if the user has quota restrictions 
  mode: 56 # Integer | 
}

begin
  #Restore SFTPGo data from a JSON backup
  result = api_instance.loaddata(input_file, opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling MaintenanceApi->loaddata: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **input_file** | **String**| Path for the file to read the JSON serialized data from. This can be an absolute path or a path relative to the configured \&quot;backups_path\&quot;. The max allowed file size is 10MB | 
 **scan_quota** | **Integer**| Quota scan:   * &#x60;0&#x60; no quota scan is done, the imported users will have used_quota_size and used_quota_files &#x3D; 0 or the existing values if they already exists. This is the default   * &#x60;1&#x60; scan quota   * &#x60;2&#x60; scan quota if the user has quota restrictions  | [optional] 
 **mode** | **Integer**|  | [optional] 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

