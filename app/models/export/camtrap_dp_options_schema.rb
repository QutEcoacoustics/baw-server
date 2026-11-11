# frozen_string_literal: true

class Export
  # The OpenAPI schema of the `options` of a camtrap_dp export.
  module CamtrapDpOptionsSchema
    Types = BawWorkers::Export::CamtrapDp::Types

    def self.schema # rubocop:disable Metrics/MethodLength
      {
        type: 'object',
        description: 'Settings for the generator of the given `export_type`. ' \
                     'For `camtrap_dp`: `contributors`, `project_capture_method` and ' \
                     '`project_sampling_design` are required.',
        properties: {
          contributors: {
            type: 'array',
            description: 'https://camtrap-dp.tdwg.org/metadata/#contributors',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string', minLength: 1 },
                organization: { type: 'string', minLength: 1 },
                email: { type: 'string', minLength: 1 },
                path: { type: 'string', format: 'uri', description: 'A URL for the contributor.' },
                role: { type: 'string', enum: Types::Role.values, default: 'contributor' }
              },
              required: [:title]
            }
          },
          project_capture_method: {
            type: 'array',
            description: 'https://camtrap-dp.tdwg.org/metadata/#project',
            items: { type: 'string', enum: Types::CaptureMethod.values }
          },
          project_sampling_design: {
            type: 'string',
            description: 'https://camtrap-dp.tdwg.org/metadata/#project',
            enum: Types::SamplingDesign.values
          },
          forced_timezone: {
            type: ['null', 'string'],
            description: 'A timezone identifier used for all timestamps in the package. ' \
                         'Must be a valid timezone when not null or blank.'
          },
          emit_project_license: { type: 'boolean',
                                  description: 'Whether to emit the project license in the export.' }
        }
      }.freeze
    end
  end
end
