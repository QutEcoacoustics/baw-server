# SftpgoGeneratedClient::S3Config

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**bucket** | **String** |  | 
**region** | **String** |  | 
**access_key** | **String** |  | [optional] 
**access_secret** | **String** | the access secret is stored encrypted (AES-256-GCM) | [optional] 
**endpoint** | **String** | optional endpoint | [optional] 
**storage_class** | **String** |  | [optional] 
**upload_part_size** | **Integer** | the buffer size (in MB) to use for multipart uploads. The minimum allowed part size is 5MB, and if this value is set to zero, the default value (5MB) for the AWS SDK will be used. The minimum allowed value is 5. | [optional] 
**upload_concurrency** | **Integer** | the number of parts to upload in parallel. If this value is set to zero, the default value (2) will be used | [optional] 
**key_prefix** | **String** | key_prefix is similar to a chroot directory for a local filesystem. If specified the user will only see contents that starts with this prefix and so you can restrict access to a specific virtual folder. The prefix, if not empty, must not start with \&quot;/\&quot; and must end with \&quot;/\&quot;. If empty the whole bucket contents will be available | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::S3Config.new(bucket: null,
                                 region: null,
                                 access_key: null,
                                 access_secret: null,
                                 endpoint: null,
                                 storage_class: null,
                                 upload_part_size: null,
                                 upload_concurrency: null,
                                 key_prefix: folder/subfolder/)
```


