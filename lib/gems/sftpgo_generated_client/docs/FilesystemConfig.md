# SftpgoGeneratedClient::FilesystemConfig

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**provider** | **Integer** | Providers:   * &#x60;0&#x60; - local filesystem   * &#x60;1&#x60; - S3 Compatible Object Storage   * &#x60;2&#x60; - Google Cloud Storage  | [optional] 
**s3config** | [**S3Config**](S3Config.md) |  | [optional] 
**gcsconfig** | [**GCSConfig**](GCSConfig.md) |  | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::FilesystemConfig.new(provider: null,
                                 s3config: null,
                                 gcsconfig: null)
```


