# SftpgoGeneratedClient::VirtualFolder

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **Integer** |  | [optional] 
**mapped_path** | **String** | absolute filesystem path to use as virtual folder. This field is unique | 
**used_quota_size** | **Integer** |  | [optional] 
**used_quota_files** | **Integer** |  | [optional] 
**last_quota_update** | **Integer** | Last quota update as unix timestamp in milliseconds | [optional] 
**users** | **Array&lt;String&gt;** | list of usernames associated with this virtual folder | [optional] 
**virtual_path** | **String** |  | 
**quota_size** | **Integer** | Quota as size in bytes. 0 menas unlimited, -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 
**quota_files** | **Integer** | Quota as number of files. 0 menas unlimited, , -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::VirtualFolder.new(id: null,
                                 mapped_path: null,
                                 used_quota_size: null,
                                 used_quota_files: null,
                                 last_quota_update: null,
                                 users: null,
                                 virtual_path: null,
                                 quota_size: null,
                                 quota_files: null)
```


