# frozen_string_literal: true

module FileSystems
  # emits json schema for DirectoryWrapper responses
  module Schema
    def self.schema(additional_data_props:)
      {
        type: 'object',
        properties: {
          path: { type: 'string' },
          name: { type: 'string' },
          link: { type: 'string', format: 'uri-reference' },
          children: {
            type: 'array',
            items: {
              anyOf: [
                # Directory
                {
                  type: 'object',
                  properties: {
                    path: { type: 'string' },
                    name: { type: 'string' },
                    has_children: { type: 'boolean' },
                    link: { type: ['string', 'null'], format: 'uri-reference' }

                  },
                  required: ['path', 'name', 'has_children'],
                  additionalProperties: false
                },
                # File
                {
                  type: 'object',
                  properties: {
                    path: { type: 'string' },
                    name: { type: 'string' },
                    has_children: { type: 'boolean' },
                    size: { type: 'integer' },
                    mime: { type: 'string' }
                  },
                  required: ['path', 'name', 'size', 'mime'],
                  additionalProperties: false
                }
              ]
            }
          },
          **additional_data_props

        },
        required: ['path', 'name', 'children'],
        readOnly: true,
        additionalProperties: false
      }
    end
  end
end
