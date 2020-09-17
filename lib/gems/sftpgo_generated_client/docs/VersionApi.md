# SftpgoGeneratedClient::VersionApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_version**](VersionApi.md#get_version) | **GET** /version | Get version details



## get_version

> VersionInfo get_version

Get version details

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

api_instance = SftpgoGeneratedClient::VersionApi.new

begin
  #Get version details
  result = api_instance.get_version
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling VersionApi->get_version: #{e}"
end
```

### Parameters

This endpoint does not need any parameter.

### Return type

[**VersionInfo**](VersionInfo.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

