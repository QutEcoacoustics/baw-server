# frozen_string_literal: true

require 'swagger_helper'

describe 'audio_events/group_by', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization

  let(:skip_automatic_description) { true }

  def self.body_schema
    Api::Schema.standard_array_response(
      {
        type: 'object',
        additionalProperties: false,
        properties: {
          site_id: Api::Schema.id,
          region_id: Api::Schema.id(nullable: true),
          project_ids: {
            type: 'array',
            items: Api::Schema.id
          },
          location_obfuscated: { type: 'boolean' },
          latitude: { type: ['number', 'null'], minimum: -90, maximum: 90 },
          longitude: { type: ['number', 'null'], minimum: -180, maximum: 180 },
          audio_event_count: { type: 'integer' }
        },
        required: [
          :site_id, :region_id, :project_ids, :location_obfuscated,
          :latitude, :longitude, :audio_event_count
        ]
      }
    )
  end

  path '/audio_events/group_by/sites' do
    get 'Gets audio events grouped by site' do
      tags 'audio_events'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns a list of sites with counts of audio events per site.
        The filter parameter is applied to audio events (not sites).
        Results only include sites the user has reader access to.
        Location coordinates may be obfuscated based on user permissions.
      DESCRIPTION

      response '200', 'audio events grouped by site retrieved' do
        schema(**body_schema)

        run_test! do
          expect_json_response
          expect(api_result).to include(:data)
        end
      end
    end

    post 'Gets audio events grouped by site with filter' do
      tags 'audio_events'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns a list of sites with counts of audio events per site.
        The filter parameter is applied to audio events (not sites).
        Results only include sites the user has reader access to.
        Location coordinates may be obfuscated based on user permissions.
      DESCRIPTION

      parameter name: :filter_body, in: :body, required: false,
        schema: Api::Schema.filter_payload(filter: true, sorting: false, paging: false, projection: false)

      response '200', 'audio events grouped by site retrieved' do
        schema(**body_schema)

        let(:filter_body) { {} }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio events by tag' do
        let(:filter_body) do
          {
            filter: {
              'tags.id': {
                eq: tag.id
              }
            }
          }
        end

        run_test! do
          expect_at_least_one_item
        end
      end

      response '422', 'rejects paging parameters' do
        let(:filter_body) { { paging: { items: 10 } } }

        run_test! do
          expect_error(
            :unprocessable_entity,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by requests.'
          )
        end
      end

      response '422', 'rejects sort parameters' do
        let(:filter_body) { { sort: { order_by: 'id' } } }

        run_test! do
          expect_error(
            :unprocessable_entity,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by requests.'
          )
        end
      end

      response '422', 'rejects projection parameters' do
        let(:filter_body) { { projection: { only: [:id] } } }

        run_test! do
          expect_error(
            :unprocessable_entity,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by requests.'
          )
        end
      end
    end
  end
end
