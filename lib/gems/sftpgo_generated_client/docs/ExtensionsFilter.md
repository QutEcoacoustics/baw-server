# SftpgoGeneratedClient::ExtensionsFilter

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**path** | **String** | exposed SFTPGo path, if no other specific filter is defined, the filter apply for sub directories too. For example if filters are defined for the paths \&quot;/\&quot; and \&quot;/sub\&quot; then the filters for \&quot;/\&quot; are applied for any file outside the \&quot;/sub\&quot; directory | [optional] 
**allowed_extensions** | **Array&lt;String&gt;** | list of, case insensitive, allowed files extension. Shell like expansion is not supported so you have to specify &#x60;.jpg&#x60; and not &#x60;*.jpg&#x60; | [optional] 
**denied_extensions** | **Array&lt;String&gt;** | list of, case insensitive, denied files extension. Denied file extensions are evaluated before the allowed ones | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::ExtensionsFilter.new(path: null,
                                 allowed_extensions: [&quot;.jpg&quot;,&quot;.png&quot;],
                                 denied_extensions: [&quot;.zip&quot;])
```


