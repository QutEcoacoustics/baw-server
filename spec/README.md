# Spec

Test types and folders are based on the conventional `Rspec` [directory
structure](https://rspec.info/features/7-0/rspec-rails/directory-structure/).

## API specs

Specs for the API are organised into different folders, based on separation of concerns:

- those that test permissions
    - modelled as request spec in the `spec/permissions` folder
- those that test capabilities
  - modelled as request spec in the `spec/capabilities` folder
- those that test specific functionality
  - modelled as request spec in the `spec/requests` folder
- those that document and validate the API
  - in the `/spec/api` folder

This separation also facilitates the use of different helpers and configurations
for each type of test (see the `spec/support` folder).

### Permissions

If the test is related to a permission, i.e. what user is allowed to invoke
which actions, it should be a permission spec (`spec/permissions`).

When testing permissions, the permissions helper methods will check that every
case of user and action combination is covered, and fail if not.

### API documentation and validation

If the test is related to the shape of the request or response, it should be an
api spec, and placed in the `/spec/api` folder. These tests document the API by
validating the request and response bodies according to the defined schemas[^1],
supported by the `rswag` gem. They are used to generate Swagger files that can
be exposed as YAML endpoints.

Note that all api specs are run as  the `admin_user`.

### Requests - Specific functionality

API tests that aren't covered by either the permissions or
documentation/validation categories (such as complex behaviours) can be a request
spec (`/spec/requests`).

### Deprecated tests

All tests in `spec/acceptance` are deprecated and should be replaced
when opportunities arrive.

## Factories

The `factory_bot` gem is used to create test data. Factories are defined in the
`spec/factories` folder.

Run the `rake factory_bot:lint` task to lint factories.

[^1]: Refer to `app/modules/api/schema.rb` for the OpenAPI schema definitions;
    model-specific schemas are defined within their respective model classes.

