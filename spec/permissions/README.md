# Permission specs

Goal of permission specs is to test permissions only.

- should test permissions
- should not test functionality
- should not test result formats or spec adherence
- but should assert that the response contains (or does not contain) results relevant to the given project permissions
- should only test response code

The specs in this directory use a custom DSL defined by `support/permissions_helper.rb`.
See that file for examples of defined functions.


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

You can also filter on specific actions:

```
rspec /requests/permissions -t destroy
rspec /requests/permissions -t ~filter
```

Or filter on both:

```
rspec /requests/permissions -t ~admin -t destroy
```
