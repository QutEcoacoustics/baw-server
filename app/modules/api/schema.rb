# frozen_string_literal: true

# Namespace module for API related functionality.
module Api
  # The OpenAPI schema for the API.
  module Schema
    extend Helpers

    RESOURCES_PATH = Rails.root.join('swagger/v2/defs/resources.json').freeze

    DEFINITION = {
      'v2/swagger.yaml' => {
        openapi: '3.0.1',
        info: {
          title: 'Acoustic Workbench API',
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
            url: '{protocol}://{authority}',
            variables: {
              authority: {
                default: 'localhost:3000'
              },
              protocol: {
                enum: [
                  'http',
                  'https'
                ],
                default: 'http'
              }
            }
          }
        ],
        components: {

          securitySchemes: {
            auth_token_header: {
              type: :apiKey,
              description: <<~MARKDOWN,
                The api auth_token placed in the 'Authorization' header.
                Example:

                ```
                Token token="xxxxxxxxxx"
                ```

                Where the your auth_token is substituted into the placeholder.
              MARKDOWN
              in: :header,
              name: 'Authorization',
              scheme: 'Token'

            },
            auth_token_query_string: {
              type: :apiKey,
              name: 'user_token',
              in: :query_string
            },
            cookie: {
              type: :apiKey,
              name: 'cookie',
              scheme: :apiKey,
              in: :header
            },
            jwt: {
              type: :bearer,
              name: 'Authorization',
              in: :header
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
                  width: { type: 'integer', nullable: true },
                  height: { type: 'integer', nullable: true }
                }
              }
            },
            permission_levels: {
              type: 'string',
              nullable: true,
              enum: [*Access::Core.levels, nil]
            },
            meta: {
              properties: {
                capabilities: {
                  type: 'object',
                  items: {
                    type: 'object',
                    properties: {
                      can: {
                        type: ['null', 'boolean']
                      },
                      details: {
                        type: 'string'
                      }
                    },
                    required: [
                      'can'
                    ]
                  }
                }
              },
              type: 'object'
            },
            meta_error: {
              type: 'object',
              properties: {
                error: {
                  type: 'object',
                  additionalProperties: false,
                  properties: {
                    details: {
                      description: 'A human readable description of the error',
                      type: 'string'
                    },
                    info: {
                      description: 'Freeform additional information about the error',
                      type: ['null', 'object', 'string', 'array']
                    },
                    links: {
                      type: 'object',
                      items: {
                        type: 'object',
                        properties: {
                          text: {
                            type: 'string'
                          },
                          url: {
                            type: 'string'
                          }
                        }
                      },
                      required: ['text']
                    }
                  }
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
            security: {
              type: 'object',
              required: [:user_name, :auth_token, :user_id],
              properties: {
                user_name: { type: 'string', readOnly: true },
                auth_token: { type: 'string', readOnly: true },
                user_id: id,
                message: { type: 'string', readOnly: true }
              }
            },
            stats: {
              type: 'object',
              required: [:summary, :recent],
              properties: {
                summary: {
                  type: 'object',
                  properties: {
                    users_online: { type: 'integer' },
                    users_total: { type: 'integer' },
                    online_window_start: { type: 'string', format: 'date-time', readOnly: true },
                    projects_total: { type: 'integer' },
                    regions_total: { type: 'integer' },
                    sites_total: { type: 'integer' },
                    annotations_total: { type: 'integer' },
                    annotations_total_duration: { type: 'number' },
                    annotations_recent: { type: 'integer' },
                    audio_recordings_total: { type: 'integer' },
                    audio_recordings_recent: { type: 'integer' },
                    audio_recordings_total_duration: { type: 'number' },
                    audio_recordings_total_size: { type: 'integer' },
                    tags_total: { type: 'integer' },
                    tags_applied_total: { type: 'integer' },
                    tags_applied_unique_total: { type: 'integer' }
                  }
                },
                recent: {
                  type: 'object',
                  properties: {
                    audio_recording_ids: {
                      type: 'array',
                      items: { '$ref' => '#/components/schemas/id' }
                    },
                    audio_event_ids: {
                      type: 'array',
                      items: { '$ref' => '#/components/schemas/id' }
                    }
                  }
                }
              },
              additionalProperties: false
            },
            polynomial: {
              type: 'object',
              properties: {
                coefficients: {
                  description: 'The coefficients of the polynomial in descending order of exponent.',
                  type: 'array',
                  items: {
                    type: 'number'
                  },
                  property: {
                    type: 'string',
                    enum: ['size', 'duration']
                  }
                },
                additionalProperties: false,
                required: ['coefficients', 'property']
              }
            },
            constant_or_polynomial: {
              oneOf: [
                { type: 'null' },
                { '$ref' => '#/components/schemas/polynomial' },
                { type: 'number' }
              ]
            },
            resources: {
              type: 'object',
              properties: {
                ncpus: { '$ref' => '#/components/schemas/constant_or_polynomial' },
                mem: { '$ref' => '#/components/schemas/constant_or_polynomial' },
                walltime: { '$ref' => '#/components/schemas/constant_or_polynomial' },
                ngpus: { '$ref' => '#/components/schemas/constant_or_polynomial' }
              }
            },
            project: Project.schema,
            analysis_job: AnalysisJob.schema,
            analysis_jobs_item: AnalysisJobsItem.schema,
            bookmark: Bookmark.schema,
            dataset: Dataset.schema,
            saved_search: SavedSearch.schema,
            script: Script.schema,
            site: Site.schema,
            region: Region.schema,
            audio_recording: AudioRecording.schema,
            permission: Permission.schema,
            harvest: Harvest.schema,
            harvest_item: HarvestItem.schema,
            audio_event_import: AudioEventImport.schema,
            audio_event_import_file: AudioEventImportFile.schema,
            audio_event: AudioEvent.schema,
            provenance: Provenance.schema
          },
          parameters: {
            'archived-parameter': archived_parameter
          }
        }
      }
    }.freeze
  end
end
