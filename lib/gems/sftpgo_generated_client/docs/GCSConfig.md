# SftpgoGeneratedClient::GCSConfig

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**bucket** | **String** |  | 
**credentials** | **String** | Google Cloud Storage JSON credentials base64 encoded. This field must be populated only when adding/updating a user. It will be always omitted, since there are sensitive data, when you search/get users. The credentials will be stored in the configured \&quot;credentials_path\&quot; | [optional] 
**automatic_credentials** | **Integer** | Automatic credentials:   * &#x60;0&#x60; - disabled, explicit credentials, using a JSON credentials file, must be provided. This is the default value if the field is null   * &#x60;1&#x60; - enabled, we try to use the Application Default Credentials (ADC) strategy to find your application&#39;s credentials  | [optional] 
**storage_class** | **String** |  | [optional] 
**key_prefix** | **String** | key_prefix is similar to a chroot directory for a local filesystem. If specified the user will only see contents that starts with this prefix and so you can restrict access to a specific virtual folder. The prefix, if not empty, must not start with \&quot;/\&quot; and must end with \&quot;/\&quot;. If empty the whole bucket contents will be available | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::GCSConfig.new(bucket: null,
                                 credentials: null,
                                 automatic_credentials: null,
                                 storage_class: null,
                                 key_prefix: folder/subfolder/)
```


