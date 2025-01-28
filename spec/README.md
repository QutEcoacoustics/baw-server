# Spec

To determine the convention for test types and folders see:
https://relishapp.com/rspec/rspec-rails/v/4-0/docs/directory-structure

## Factories

Run the `rake factory_bot:lint` task to lint factories.

## API specs

Specs for the API come in a few forms:

- those that test permissions
    - modelled as request spec in the `spec/permissions` folder
- those that test capabilities
  - modelled as request spec in the `spec/capabilities` folder
- those that test specific functionality
  - modelled as request spec in the `spec/requests` folder
- those that document and validate the API
  - in the `/spec/api` folder

API docs test API responses, and validate API request and response
bodies according to schemas. These are supported by the
`rswag` gem and should be placed in the `api` folder.

All tests in `spec/acceptance` are deprecated and should be replaced
when opportunities arrive.
