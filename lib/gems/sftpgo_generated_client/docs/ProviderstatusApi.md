# SftpgoGeneratedClient::ProviderstatusApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_provider_status**](ProviderstatusApi.md#get_provider_status) | **GET** /providerstatus | Get data provider status



## get_provider_status

> ApiResponse get_provider_status

Get data provider status

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

api_instance = SftpgoGeneratedClient::ProviderstatusApi.new

begin
  #Get data provider status
  result = api_instance.get_provider_status
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling ProviderstatusApi->get_provider_status: #{e}"
end
```

### Parameters

This endpoint does not need any parameter.

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

