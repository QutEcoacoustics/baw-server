# Spec

To determine the convention for test types and folders see:
https://relishapp.com/rspec/rspec-rails/v/4-0/docs/directory-structure

## Factories

Run the `rake factory_bot:lint` task to lint factories.

## API specs

Specs for the API come in three forms:

- those that test permissions
- those that test specific functionality
- those that document and validate the API

The former two variants (permissions and functionality) should
be modelled as request specs and placed in the `specs/requests`
folder.

API docs test API responses, and validate API request and response
bodies according to schemas. These are supported by the
`rswag` gem and should be placed in the API folder.
