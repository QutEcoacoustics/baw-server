# SftpgoGeneratedClient::Transfer

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**operation_type** | **String** |  | [optional] 
**path** | **String** | file path for the upload/download | [optional] 
**start_time** | **Integer** | start time as unix timestamp in milliseconds | [optional] 
**size** | **Integer** | bytes transferred | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::Transfer.new(operation_type: null,
                                 path: null,
                                 start_time: null,
                                 size: null)
```


