# SftpgoGeneratedClient::UserFilters

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**allowed_ip** | **Array&lt;String&gt;** | only clients connecting from these IP/Mask are allowed. IP/Mask must be in CIDR notation as defined in RFC 4632 and RFC 4291, for example \&quot;192.0.2.0/24\&quot; or \&quot;2001:db8::/32\&quot; | [optional] 
**denied_ip** | **Array&lt;String&gt;** | clients connecting from these IP/Mask are not allowed. Denied rules are evaluated before allowed ones | [optional] 
**denied_login_methods** | [**Array&lt;LoginMethods&gt;**](LoginMethods.md) | if null or empty any available login method is allowed | [optional] 
**denied_protocols** | [**Array&lt;SupportedProtocols&gt;**](SupportedProtocols.md) | if null or empty any available protocol is allowed | [optional] 
**file_extensions** | [**Array&lt;ExtensionsFilter&gt;**](ExtensionsFilter.md) | filters based on file extensions. These restrictions do not apply to files listing for performance reasons, so a denied file cannot be downloaded/overwritten/renamed but it will still be listed in the list of files. Please note that these restrictions can be easily bypassed | [optional] 
**max_upload_file_size** | **Integer** | maximum allowed size, as bytes, for a single file upload. The upload will be aborted if/when the size of the file being sent exceeds this limit. 0 means unlimited. This restriction does not apply for SSH system commands such as &#x60;git&#x60; and &#x60;rsync&#x60; | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::UserFilters.new(allowed_ip: [&quot;192.0.2.0/24&quot;,&quot;2001:db8::/32&quot;],
                                 denied_ip: [&quot;172.16.0.0/16&quot;],
                                 denied_login_methods: null,
                                 denied_protocols: null,
                                 file_extensions: null,
                                 max_upload_file_size: null)
```


