# SftpgoGeneratedClient::User

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **Integer** |  | [optional] 
**status** | **Integer** | status:   * &#x60;0&#x60; user is disabled, login is not allowed   * &#x60;1&#x60; user is enabled  | [optional] 
**username** | **String** | username is unique | [optional] 
**expiration_date** | **Integer** | expiration date as unix timestamp in milliseconds. An expired account cannot login. 0 means no expiration | [optional] 
**password** | **String** | password or public key/SSH user certificate are mandatory. If the password has no known hashing algo prefix it will be stored using argon2id. You can send a password hashed as bcrypt or pbkdf2 and it will be stored as is. For security reasons this field is omitted when you search/get users | [optional] 
**public_keys** | **Array&lt;String&gt;** | a password or at least one public key/SSH user certificate are mandatory. | [optional] 
**home_dir** | **String** | path to the user home directory. The user cannot upload or download files outside this directory. SFTPGo tries to automatically create this folder if missing. Must be an absolute path | [optional] 
**virtual_folders** | [**Array&lt;VirtualFolder&gt;**](VirtualFolder.md) | mapping between virtual SFTPGo paths and filesystem paths outside the user home directory. Supported for local filesystem only. If one or more of the specified folders are not inside the dataprovider they will be automatically created. You have to create the folder on the filesystem yourself | [optional] 
**uid** | **Integer** | if you run SFTPGo as root user, the created files and directories will be assigned to this uid. 0 means no change, the owner will be the user that runs SFTPGo. Ignored on windows | [optional] 
**gid** | **Integer** | if you run SFTPGo as root user, the created files and directories will be assigned to this gid. 0 means no change, the group will be the one of the user that runs SFTPGo. Ignored on windows | [optional] 
**max_sessions** | **Integer** | Limit the sessions that a user can open. 0 means unlimited | [optional] 
**quota_size** | **Integer** | Quota as size in bytes. 0 menas unlimited. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 
**quota_files** | **Integer** | Quota as number of files. 0 menas unlimited. Please note that quota is updated if files are added/removed via SFTPGo otherwise a quota scan or a manual quota update is needed | [optional] 
**permissions** | **Array&lt;Hash&gt;** |  | [optional] 
**used_quota_size** | **Integer** |  | [optional] 
**used_quota_files** | **Integer** |  | [optional] 
**last_quota_update** | **Integer** | Last quota update as unix timestamp in milliseconds | [optional] 
**upload_bandwidth** | **Integer** | Maximum upload bandwidth as KB/s, 0 means unlimited | [optional] 
**download_bandwidth** | **Integer** | Maximum download bandwidth as KB/s, 0 means unlimited | [optional] 
**last_login** | **Integer** | Last user login as unix timestamp in milliseconds | [optional] 
**filters** | [**UserFilters**](UserFilters.md) |  | [optional] 
**filesystem** | [**FilesystemConfig**](FilesystemConfig.md) |  | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::User.new(id: null,
                                 status: null,
                                 username: null,
                                 expiration_date: null,
                                 password: null,
                                 public_keys: null,
                                 home_dir: null,
                                 virtual_folders: null,
                                 uid: null,
                                 gid: null,
                                 max_sessions: null,
                                 quota_size: null,
                                 quota_files: null,
                                 permissions: {&quot;/&quot;:[&quot;*&quot;],&quot;/somedir&quot;:[&quot;list&quot;,&quot;download&quot;]},
                                 used_quota_size: null,
                                 used_quota_files: null,
                                 last_quota_update: null,
                                 upload_bandwidth: null,
                                 download_bandwidth: null,
                                 last_login: null,
                                 filters: null,
                                 filesystem: null)
```


