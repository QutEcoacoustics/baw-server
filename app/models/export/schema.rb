# frozen_string_literal: true

class Export
  # The OpenAPI schemas for the exports API, extended onto Export
  module Schema
    def schema # rubocop:disable Metrics/MethodLength
      {
        type: 'object',
        additionalProperties: false,
        properties: {
          id: Api::Schema.id,
          name: {
            type: 'string',
            minLength: 2,
            maxLength: 255,
            description: 'The title of the exported package.'
          },
          export_type: {
            type: 'string',
            enum: Export::EXPORT_TYPE_ENUM.values,
            description: 'The kind of package to generate, which also determines the shape of `options`.'
          },
          project_id: Api::Schema.id(read_only: false).merge(
            description: 'The project to export data from.' \
                         'The current user must have at least reader access to the project.'
          ),
          filter: {
            type: 'object',
            description: 'A filter applied to the data being exported (the taggings of audio events in the ' \
                         'project), in the same format as the `filter` property of a filter request body. ' \
                         'It must be the inner filter only: it cannot contain `filter`, `projection`, `paging`, ' \
                         'or `sorting` keys. Use `{}` to export everything the creator can access in the project.'
          },
          options: { oneOf: Export::EXPORT_TYPE_ENUM.values.map { |type|
            const_get("#{type.camelize}OptionsSchema", false).schema
          } },
          obfuscate_locations: {
            type: ['null', 'boolean'],
            description: 'Whether the locations of sites in the export are obfuscated. ' \
                         '`null` (the default) decides from the creator\'s permissions when the export is ' \
                         'generated: locations are not obfuscated for an owner of the project, and are ' \
                         'obfuscated for everyone else. ' \
                         '`true` always obfuscates locations. ' \
                         '`false` never obfuscates locations, and is only accepted when the creator is an ' \
                         'owner of the project. ' \
                         'An export with `false` is also refused at generation and download time if the ' \
                         'creator is no longer an owner of the project.'
          },
          status: {
            type: 'string',
            enum: Export::STATUS_ENUM.values,
            readOnly: true,
            description: 'Where the export is in its life cycle: a new export is `queued` straight after ' \
                         'creation, then `working` while being generated, then `ready` (the file can be ' \
                         'downloaded) or `failed` (see `error`). A `ready` export can be downloaded until ' \
                         '`expires_at`, or until it is purged.'
          },
          error: {
            type: ['null', 'string'],
            readOnly: true,
            description: 'A message explaining why generation failed. Only set when `status` is `failed`.'
          },
          started_at: Api::Schema.date(nullable: true, read_only: true),
          finished_at: Api::Schema.date(nullable: true, read_only: true),
          expires_at: Api::Schema.date(nullable: true, read_only: true).merge(
            description: 'When the file stops being available for download. Only set once `status` is `ready`.'
          ),
          purged: {
            type: ['null', 'boolean'],
            readOnly: true,
            description: 'True when the file has been removed. A purged export is `ready` but cannot be downloaded.'
          },
          download_count: {
            type: ['null', 'integer'],
            readOnly: true,
            description: 'The number of times the file has been downloaded.'
          },
          **Api::Schema.creator_user_stamp,
          updated_at: Api::Schema.date(read_only: true)
        },
        required: [
          :id,
          :name,
          :export_type,
          :project_id,
          :filter,
          :options,
          :obfuscate_locations,
          :status,
          :error,
          :started_at,
          :finished_at,
          :expires_at,
          :purged,
          :download_count,
          :creator_id,
          :created_at,
          :updated_at
        ]
      }.freeze
    end

    # The schema of the response to creating an export. It is the export plus a token and download
    # url that can be used to download the export without logging in.
    def create_response_schema
      schema.merge(
        properties: schema[:properties].merge(
          token: {
            type: 'string',
            readOnly: true,
            description: 'A signed token that identifies this export. Sent as the `token` query string ' \
                         'parameter of the download endpoint, it allows the file to be downloaded without ' \
                         'logging in. Only returned when the export is created. The download is still refused ' \
                         'if the export has expired or been purged, or if the creator has lost access to the ' \
                         'project.'
          },
          exchange_url: {
            type: 'string',
            format: 'uri',
            readOnly: true,
            description: 'The URL of the download endpoint for this export, including the `token` parameter.' \
          }
        ),
        required: schema[:required] + [:token, :exchange_url]
      ).freeze
    end
  end
end
