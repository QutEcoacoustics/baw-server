# SftpgoGeneratedClient::VersionInfo

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**version** | **String** |  | [optional] 
**build_date** | **String** |  | [optional] 
**commit_hash** | **String** |  | [optional] 
**features** | **Array&lt;String&gt;** | Features for the current build. Available features are \&quot;portable\&quot;, \&quot;bolt\&quot;, \&quot;mysql\&quot;, \&quot;sqlite\&quot;, \&quot;pgsql\&quot;, \&quot;s3\&quot;, \&quot;gcs\&quot;, \&quot;metrics\&quot;. If a feature is available it has a \&quot;+\&quot; prefix, otherwise a \&quot;-\&quot; prefix | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::VersionInfo.new(version: null,
                                 build_date: null,
                                 commit_hash: null,
                                 features: null)
```


