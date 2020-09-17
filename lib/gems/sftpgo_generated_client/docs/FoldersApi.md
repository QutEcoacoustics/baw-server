# SftpgoGeneratedClient::FoldersApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**add_folder**](FoldersApi.md#add_folder) | **POST** /folder | Adds a new folder
[**delete_folder**](FoldersApi.md#delete_folder) | **DELETE** /folder | Delete an existing folder
[**get_folders**](FoldersApi.md#get_folders) | **GET** /folder | Returns an array with one or more folders



## add_folder

> BaseVirtualFolder add_folder(base_virtual_folder)

Adds a new folder

a new folder with the specified mapped_path will be added. To update the used quota parameters a quota scan is needed

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

api_instance = SftpgoGeneratedClient::FoldersApi.new
base_virtual_folder = SftpgoGeneratedClient::BaseVirtualFolder.new # BaseVirtualFolder | 

begin
  #Adds a new folder
  result = api_instance.add_folder(base_virtual_folder)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling FoldersApi->add_folder: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **base_virtual_folder** | [**BaseVirtualFolder**](BaseVirtualFolder.md)|  | 

### Return type

[**BaseVirtualFolder**](BaseVirtualFolder.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json


## delete_folder

> ApiResponse delete_folder(folder_path)

Delete an existing folder

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

api_instance = SftpgoGeneratedClient::FoldersApi.new
folder_path = 'folder_path_example' # String | path to the folder to delete

begin
  #Delete an existing folder
  result = api_instance.delete_folder(folder_path)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling FoldersApi->delete_folder: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **folder_path** | **String**| path to the folder to delete | 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## get_folders

> Array&lt;BaseVirtualFolder&gt; get_folders(opts)

Returns an array with one or more folders

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

api_instance = SftpgoGeneratedClient::FoldersApi.new
opts = {
  offset: 0, # Integer | 
  limit: 100, # Integer | The maximum number of items to return. Max value is 500, default is 100
  order: 'ASC', # String | Ordering folders by path. Default ASC
  folder_path: 'folder_path_example' # String | Filter by folder path, extact match case sensitive
}

begin
  #Returns an array with one or more folders
  result = api_instance.get_folders(opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling FoldersApi->get_folders: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **offset** | **Integer**|  | [optional] [default to 0]
 **limit** | **Integer**| The maximum number of items to return. Max value is 500, default is 100 | [optional] [default to 100]
 **order** | **String**| Ordering folders by path. Default ASC | [optional] 
 **folder_path** | **String**| Filter by folder path, extact match case sensitive | [optional] 

### Return type

[**Array&lt;BaseVirtualFolder&gt;**](BaseVirtualFolder.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

