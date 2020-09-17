# SftpgoGeneratedClient::ConnectionsApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**close_connection**](ConnectionsApi.md#close_connection) | **DELETE** /connection/{connectionID} | Terminate an active connection
[**get_connections**](ConnectionsApi.md#get_connections) | **GET** /connection | Get the active users and info about their uploads/downloads



## close_connection

> ApiResponse close_connection(connection_id)

Terminate an active connection

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

api_instance = SftpgoGeneratedClient::ConnectionsApi.new
connection_id = 'connection_id_example' # String | ID of the connection to close

begin
  #Terminate an active connection
  result = api_instance.close_connection(connection_id)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling ConnectionsApi->close_connection: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **connection_id** | **String**| ID of the connection to close | 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## get_connections

> Array&lt;ConnectionStatus&gt; get_connections

Get the active users and info about their uploads/downloads

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

api_instance = SftpgoGeneratedClient::ConnectionsApi.new

begin
  #Get the active users and info about their uploads/downloads
  result = api_instance.get_connections
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling ConnectionsApi->get_connections: #{e}"
end
```

### Parameters

This endpoint does not need any parameter.

### Return type

[**Array&lt;ConnectionStatus&gt;**](ConnectionStatus.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

