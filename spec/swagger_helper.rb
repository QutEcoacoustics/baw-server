# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # this helps with generating examples apparently
  config.swagger_dry_run = false

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'BAW API',
        version: 'v2'
      },
      produces: [
        'application/json'
      ],
      consumes: [
        'application/json'
      ],
      paths: {},
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: Settings.host.name
            }
          }
        }
      ],
      components: {
        securitySchemes: {
          basic_auth_with_token: {
            type: :http,
            scheme: :basic
          },
          auth_token_query_string: {
            type: :apiKey,
            name: 'auth_token',
            in: :query_string

          }
        },
        schemas: {
          id: {
            type: 'integer',
            minimum: 0,
            readOnly: true
          },
          nullableId: {
            type: ['integer', 'null'],
            minimum: 0,
            readOnly: true
          },
          timezone_information: {
            anyOf: [
              {
                type: 'object',
                properties: {
                  identifier_alt: { type: ['string', 'null'] },
                  identifier: { type: 'string' },
                  friendly_identifier: { type: 'string' },
                  utc_offset: { type: 'string' },
                  utc_total_offset: { type: 'integer' }
                }
              },
              {
                type: 'null'
              }
            ]
          },
          image_urls: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                size: { type: 'string' },
                url: { type: 'string', format: 'URI' },
                width: { type: 'integer' },
                height: { type: 'integer' }
              }
            }
          },
          permission_levels: {
            type: 'string',
            enum: ['Owner', 'Writer', 'Reader', nil]
          },
          meta: {
            type: 'object'
          },
          meta_error: {
            type: 'object',
            properties: {
              error: {
                type: 'object'

              },
              required: ['error']
            }
          },
          standard_response: {
            type: 'object',
            additionalProperties: false,
            properties: {
              meta: {
                '$ref' => '#/components/schemas/meta'
              },
              data: {
                oneOf: [{ type: 'array' }, { type: 'object' }]
              }
            },
            required: ['meta', 'data']
          },
          error_response: {
            type: 'object',
            additionalProperties: false,
            properties: {
              meta: {
                allOf: [
                  { '$ref' => '#/components/schemas/meta' },
                  { '$ref' => '#/components/schemas/meta_error' }
                ]
              },
              data: {
                type: 'null'
              }
            },
            required: ['meta', 'data']
          },
          cms_blob: {
            type: 'object',
            required: [
              'id',
              'site_id',
              'layout_id',
              'parent_id',
              'target_page_id',
              'label',
              'slug',
              'full_path',
              'content',
              'position',
              'children_count',
              'is_published',
              'created_at',
              'updated_at',
              'children'
            ],
            properties: {
              id: { '$ref' => '#/components/schemas/id' },
              site_id: { '$ref' => '#/components/schemas/id' },
              layout_id: { '$ref' => '#/components/schemas/id' },
              parent_id: { '$ref' => '#/components/schemas/nullableId' },
              target_page_id: { '$ref' => '#/components/schemas/nullableId' },
              label: { type: 'string' },
              slug: { type: 'string' },
              full_path: { type: 'string', format: 'uri-reference' },
              content: { type: 'string', format: 'html' },
              position: { type: 'integer' },
              children_count: { type: 'integer' },
              is_published: { type: 'boolean' },
              created_at: { type: 'string', format: 'date-time', readOnly: true },
              updated_at: { type: ['null', 'string'], format: 'date-time', readOnly: true },
              children: {
                type: 'array',
                additionalItems: true,
                items: {
                  type: 'object',
                  properties: {
                    label: { type: 'string' },
                    full_path: { type: 'string', format: 'uri-reference' }
                  },
                  additionalProperties: false
                }
              }
            },
            additionalProperties: false
          },
          project: Project.schema,
          analysis_job: AnalysisJob.schema,
          bookmark: Bookmark.schema,
          dataset: Dataset.schema,
          saved_search: SavedSearch.schema,
          script: Script.schema,
          site: Site.schema,
          region: Region.schema
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end
