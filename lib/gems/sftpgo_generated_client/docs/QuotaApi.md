# SftpgoGeneratedClient::QuotaApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**folder_quota_update**](QuotaApi.md#folder_quota_update) | **PUT** /folder_quota_update | update the folder used quota limits
[**get_folders_quota_scans**](QuotaApi.md#get_folders_quota_scans) | **GET** /folder_quota_scan | Get the active quota scans for folders
[**get_quota_scans**](QuotaApi.md#get_quota_scans) | **GET** /quota_scan | Get the active quota scans for users home directories
[**quota_update**](QuotaApi.md#quota_update) | **PUT** /quota_update | update the user used quota limits
[**start_folder_quota_scan**](QuotaApi.md#start_folder_quota_scan) | **POST** /folder_quota_scan | start a new folder quota scan
[**start_quota_scan**](QuotaApi.md#start_quota_scan) | **POST** /quota_scan | start a new user quota scan



## folder_quota_update

> ApiResponse folder_quota_update(base_virtual_folder, opts)

update the folder used quota limits

Set the current used quota limits for the given folder

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

api_instance = SftpgoGeneratedClient::QuotaApi.new
base_virtual_folder = SftpgoGeneratedClient::BaseVirtualFolder.new # BaseVirtualFolder | The only folder mandatory fields are mapped_path,used_quota_size and used_quota_files. Please note that if the used quota fields are missing they will default to 0
opts = {
  mode: 'reset' # String | the update mode specifies if the given quota usage values should be added or replace the current ones
}

begin
  #update the folder used quota limits
  result = api_instance.folder_quota_update(base_virtual_folder, opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->folder_quota_update: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **base_virtual_folder** | [**BaseVirtualFolder**](BaseVirtualFolder.md)| The only folder mandatory fields are mapped_path,used_quota_size and used_quota_files. Please note that if the used quota fields are missing they will default to 0 | 
 **mode** | **String**| the update mode specifies if the given quota usage values should be added or replace the current ones | [optional] 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json


## get_folders_quota_scans

> Array&lt;FolderQuotaScan&gt; get_folders_quota_scans

Get the active quota scans for folders

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

api_instance = SftpgoGeneratedClient::QuotaApi.new

begin
  #Get the active quota scans for folders
  result = api_instance.get_folders_quota_scans
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->get_folders_quota_scans: #{e}"
end
```

### Parameters

This endpoint does not need any parameter.

### Return type

[**Array&lt;FolderQuotaScan&gt;**](FolderQuotaScan.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## get_quota_scans

> Array&lt;QuotaScan&gt; get_quota_scans

Get the active quota scans for users home directories

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

api_instance = SftpgoGeneratedClient::QuotaApi.new

begin
  #Get the active quota scans for users home directories
  result = api_instance.get_quota_scans
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->get_quota_scans: #{e}"
end
```

### Parameters

This endpoint does not need any parameter.

### Return type

[**Array&lt;QuotaScan&gt;**](QuotaScan.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## quota_update

> ApiResponse quota_update(user, opts)

update the user used quota limits

Set the current used quota limits for the given user

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

api_instance = SftpgoGeneratedClient::QuotaApi.new
user = SftpgoGeneratedClient::User.new # User | The only user mandatory fields are username,used_quota_size and used_quota_files. Please note that if the quota fields are missing they will default to 0
opts = {
  mode: 'reset' # String | the update mode specifies if the given quota usage values should be added or replace the current ones
}

begin
  #update the user used quota limits
  result = api_instance.quota_update(user, opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->quota_update: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user** | [**User**](User.md)| The only user mandatory fields are username,used_quota_size and used_quota_files. Please note that if the quota fields are missing they will default to 0 | 
 **mode** | **String**| the update mode specifies if the given quota usage values should be added or replace the current ones | [optional] 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json


## start_folder_quota_scan

> ApiResponse start_folder_quota_scan(base_virtual_folder)

start a new folder quota scan

A quota scan update the number of files and their total size for the specified folder

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

api_instance = SftpgoGeneratedClient::QuotaApi.new
base_virtual_folder = SftpgoGeneratedClient::BaseVirtualFolder.new # BaseVirtualFolder | 

begin
  #start a new folder quota scan
  result = api_instance.start_folder_quota_scan(base_virtual_folder)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->start_folder_quota_scan: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **base_virtual_folder** | [**BaseVirtualFolder**](BaseVirtualFolder.md)|  | 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json


## start_quota_scan

> ApiResponse start_quota_scan(user)

start a new user quota scan

A quota scan update the number of files and their total size for the specified user

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

api_instance = SftpgoGeneratedClient::QuotaApi.new
user = SftpgoGeneratedClient::User.new # User | 

begin
  #start a new user quota scan
  result = api_instance.start_quota_scan(user)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling QuotaApi->start_quota_scan: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user** | [**User**](User.md)|  | 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json

