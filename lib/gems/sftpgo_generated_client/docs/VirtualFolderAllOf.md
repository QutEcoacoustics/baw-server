# SftpgoGeneratedClient::VirtualFolderAllOf

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**virtual_path** | **String** |  | 
**quota_size** | **Integer** | Quota as size in bytes. 0 menas unlimited, -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 
**quota_files** | **Integer** | Quota as number of files. 0 menas unlimited, , -1 means included in user quota. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::VirtualFolderAllOf.new(virtual_path: null,
                                 quota_size: null,
                                 quota_files: null)
```


