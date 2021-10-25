# Why Read Me?

This document is an attempt to explain how some of the more magical parts of the modal classes work. Most things not covered in this list are part of the ActivateRecord class, and you should look for more relevant documentation online.

## filter_settings

This is an attempt at describing what each of the values means, and how they effect the API. This is not an exhaustive list of side-affects. If you experience behaviours outside of what is describe, update this guide for future developers.

`valid_fields`: Fields which the filter request is able to filter models by. This can include custom fields which define how they are found in the database

`render_fields`: This (combined with `custom_fields`) is the list of fields which will be returned in successful API requests. This also needs to provide any parameters required to calculate the custom_fields.

`text_fields`: Unknown. Appears to be for enabling values for partial string matching.

`custom_fields`: These are fields which are not directly stored in the DB, and must instead be calculated. Examples include generating the different description types for a model, where only the long description is stored in the DB. The values returned here will be combined with the `valid_fields` array, and returned in API requests.

`controller`: Which controller will handle the API requests

`action`: Which action will be called when a filter request is made

`defaults`: Default filter parameters for this model when filter requests are made

`valid_associations`: This is a list of other models which are associated with this model, and can be included inside a filter request. It has four properties:
  - `join`: What table to create a join with
  - `on`: DB query which returns all models associated with this model
  - `available`: Whether this association is available to be used
  - `associations`: A recursive definition of the above allowing filter requests to chain across multiple models

## schema

This property tracks how swagger should handle this route, and should be used in combination with updating the `spec/swagger_helper.rb` file to include the models schema to the list. Currently this schema is based on the OpenAPI 3.0 specification which can be found here: https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#schemaObject. When adding properties to this list, check other models to ensure type definitions are kept consistent. There also exists an Api::Schema module which contains boilerplate schema definitions for common types.
