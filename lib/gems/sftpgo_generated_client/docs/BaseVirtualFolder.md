# SftpgoGeneratedClient::BaseVirtualFolder

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **Integer** |  | [optional] 
**mapped_path** | **String** | absolute filesystem path to use as virtual folder. This field is unique | 
**used_quota_size** | **Integer** |  | [optional] 
**used_quota_files** | **Integer** |  | [optional] 
**last_quota_update** | **Integer** | Last quota update as unix timestamp in milliseconds | [optional] 
**users** | **Array&lt;String&gt;** | list of usernames associated with this virtual folder | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::BaseVirtualFolder.new(id: null,
                                 mapped_path: null,
                                 used_quota_size: null,
                                 used_quota_files: null,
                                 last_quota_update: null,
                                 users: null)
```


