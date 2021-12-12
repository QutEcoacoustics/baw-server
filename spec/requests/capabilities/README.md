# Capabilities spec

Goals of capabilities specs is to test capabilities only.

- should test capabilities
- should test capabilities for list and details endpoints
  - lists: index, filter
  - details: show, new, edit, update
- all requests should return successfully
  - we assume an errored request has already gone past the stage where a capability
    was useful. I.e. a capability advises a client if an action is possible;
    if the request has failed, the client has ignored (or was unable to ignore)
    the advice.
- should not test for spec adherence
- should not test functionality
- should test for various users


The specs in this directory use a custom DSL defined by `helpers/capabilities_helper.rb`.


## Useful filters

You can use tag filtering on the rspec to only execute certain cases.

For example, to only run examples for the `owner` user:

```
rspec /requests/permissions -t owner
```

Or every user except `admin`:

```
rspec /requests/permissions -t ~admin
```
