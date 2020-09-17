# SftpgoGeneratedClient::UsersApi

All URIs are relative to *https://raw.githubusercontent.com/api/v1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**add_user**](UsersApi.md#add_user) | **POST** /user | Adds a new user
[**delete_user**](UsersApi.md#delete_user) | **DELETE** /user/{userID} | Delete an existing user
[**get_user_by_id**](UsersApi.md#get_user_by_id) | **GET** /user/{userID} | Find user by ID
[**get_users**](UsersApi.md#get_users) | **GET** /user | Returns an array with one or more users
[**update_user**](UsersApi.md#update_user) | **PUT** /user/{userID} | Update an existing user



## add_user

> User add_user(user)

Adds a new user

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

api_instance = SftpgoGeneratedClient::UsersApi.new
user = SftpgoGeneratedClient::User.new # User | 

begin
  #Adds a new user
  result = api_instance.add_user(user)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling UsersApi->add_user: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user** | [**User**](User.md)|  | 

### Return type

[**User**](User.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json


## delete_user

> ApiResponse delete_user(user_id)

Delete an existing user

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

api_instance = SftpgoGeneratedClient::UsersApi.new
user_id = 56 # Integer | ID of the user to delete

begin
  #Delete an existing user
  result = api_instance.delete_user(user_id)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling UsersApi->delete_user: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user_id** | **Integer**| ID of the user to delete | 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## get_user_by_id

> User get_user_by_id(user_id)

Find user by ID

For security reasons the hashed password is omitted in the response

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

api_instance = SftpgoGeneratedClient::UsersApi.new
user_id = 56 # Integer | ID of the user to retrieve

begin
  #Find user by ID
  result = api_instance.get_user_by_id(user_id)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling UsersApi->get_user_by_id: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user_id** | **Integer**| ID of the user to retrieve | 

### Return type

[**User**](User.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## get_users

> Array&lt;User&gt; get_users(opts)

Returns an array with one or more users

For security reasons hashed passwords are omitted in the response

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

api_instance = SftpgoGeneratedClient::UsersApi.new
opts = {
  offset: 0, # Integer | 
  limit: 100, # Integer | The maximum number of items to return. Max value is 500, default is 100
  order: 'ASC', # String | Ordering users by username. Default ASC
  username: 'username_example' # String | Filter by username, extact match case sensitive
}

begin
  #Returns an array with one or more users
  result = api_instance.get_users(opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling UsersApi->get_users: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **offset** | **Integer**|  | [optional] [default to 0]
 **limit** | **Integer**| The maximum number of items to return. Max value is 500, default is 100 | [optional] [default to 100]
 **order** | **String**| Ordering users by username. Default ASC | [optional] 
 **username** | **String**| Filter by username, extact match case sensitive | [optional] 

### Return type

[**Array&lt;User&gt;**](User.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json


## update_user

> ApiResponse update_user(user_id, user, opts)

Update an existing user

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

api_instance = SftpgoGeneratedClient::UsersApi.new
user_id = 56 # Integer | ID of the user to update
user = SftpgoGeneratedClient::User.new # User | 
opts = {
  disconnect: 56 # Integer | Disconnect:   * `0` The user will not be disconnected and it will continue to use the old configuration until connected. This is the default   * `1` The user will be disconnected after a successful update. It must login again and so it will be forced to use the new configuration 
}

begin
  #Update an existing user
  result = api_instance.update_user(user_id, user, opts)
  p result
rescue SftpgoGeneratedClient::ApiError => e
  puts "Exception when calling UsersApi->update_user: #{e}"
end
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **user_id** | **Integer**| ID of the user to update | 
 **user** | [**User**](User.md)|  | 
 **disconnect** | **Integer**| Disconnect:   * &#x60;0&#x60; The user will not be disconnected and it will continue to use the old configuration until connected. This is the default   * &#x60;1&#x60; The user will be disconnected after a successful update. It must login again and so it will be forced to use the new configuration  | [optional] 

### Return type

[**ApiResponse**](ApiResponse.md)

### Authorization

[BasicAuth](../README.md#BasicAuth)

### HTTP request headers

- **Content-Type**: application/json
- **Accept**: application/json

