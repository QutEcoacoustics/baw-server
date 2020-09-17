# SftpgoGeneratedClient::ConnectionStatus

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**username** | **String** | connected username | [optional] 
**connection_id** | **String** | unique connection identifier | [optional] 
**client_version** | **String** | client version | [optional] 
**remote_address** | **String** | Remote address for the connected client | [optional] 
**connection_time** | **Integer** | connection time as unix timestamp in milliseconds | [optional] 
**command** | **String** | SSH command or WebDAV method | [optional] 
**last_activity** | **Integer** | last client activity as unix timestamp in milliseconds | [optional] 
**protocol** | **String** |  | [optional] 
**active_transfers** | [**Array&lt;Transfer&gt;**](Transfer.md) |  | [optional] 

## Code Sample

```ruby
require 'SftpgoGeneratedClient'

instance = SftpgoGeneratedClient::ConnectionStatus.new(username: null,
                                 connection_id: null,
                                 client_version: null,
                                 remote_address: null,
                                 connection_time: null,
                                 command: null,
                                 last_activity: null,
                                 protocol: null,
                                 active_transfers: null)
```


