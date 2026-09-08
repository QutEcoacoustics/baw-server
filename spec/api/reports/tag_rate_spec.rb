# frozen_string_literal: true

require 'swagger_helper'

describe 'reports', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization

  let(:skip_automatic_description) { true }

  def self.response_body_schema
    Api::Schema.standard_array_response(
      {
        type: 'object',
        additionalProperties: false,
        properties: {
          **Api::Schema.range,
          tags: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              properties: {
                tag_id: { type: Api::Schema.id },
                detected_manual_minutes: { type: 'integer',
                                           description: 'The number of minutes where the tag was detected from a manual source' },
                detected_analysis_minutes: { type: 'integer',
                                             description: 'The number of minutes where the tag was detected from an analysis source' },
                detected_combined_minutes: { type: 'integer',
                                             description: 'The number of distinct minutes with a tag detection from any source' }
              }
            }
          },
          site_id: { type: Api::Schema.id },
          analysis_ids: {
            type: 'array',
            items: {
              type: Api::Schema.id,
              description: 'The analysis job IDs of any analysed audio recordings for the current site and range'
            }
          },
          total_minutes: {
            type: 'number',
            description: 'The total number of minutes in the bucket for the site'
          },
          manual_events_minutes: {
            type: 'number',
            description: 'The number of minutes in the range for the site that have at least one manual tag detection'
          },
          total_analysed_minutes: {
            type: 'number',
            description: 'The number of minutes in the range for the site that have at least one successful analysis'
          }
        },
        required: [:range, :tags, :site_id, :analysis_ids, :total_minutes, :manual_events_minutes,
                   :total_analysed_minutes]
      }
    )
  end

  def self.request_body_schema
    Api::Schema.filter_payload(
      filter: true, sorting: false, paging: false, projection: false, options: Api::Schema.report_options
    )
  end

  path '/reports/tag_rate' do
    post 'Gets tag rate report per site and time bucket' do
      tags 'reports'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        # Returns tag detection counts per site and time bucket.
        # The `options` parameter specifies the bucket size (day, week, month, or year).
        # The optional `filter` parameter is applied to audio recordings.
        # Results only include audio recordings the user has reader access to.
      DESCRIPTION

      parameter name: :request_body, in: :body, required: true,
        schema: request_body_schema

      response '200', 'tag rate report retrieved' do
        schema(**response_body_schema)

        let(:request_body) { { options: { bucket_size: 'day' }, filter: {} } }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio recordings by tag' do
        let(:request_body) do
          {
            options: { bucket_size: 'day' },
            filter: { 'tags.id': { eq: tag.id } }
          }
        end

        run_test! do
          expect_at_least_one_item
        end

        response '422', 'rejects paging parameters' do
          let(:request_body) { { options: { bucket_size: 'day' }, paging: { items: 10 } } }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
            )
          end
        end

        response '422', 'rejects sort parameters' do
          let(:request_body) { { options: { bucket_size: 'day' }, sort: { order_by: 'id' } } }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
            )
          end
        end

        response '422', 'rejects projection parameters' do
          let(:request_body) { { options: { bucket_size: 'day' }, projection: { only: [:id] } } }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
            )
          end
        end

        response '422', 'rejects missing options' do
          let(:request_body) { { filter: {} } }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: param is missing or the value is empty or invalid: options'
            )
          end
        end

        response '422', 'rejects empty options' do
          let(:request_body) {
            {
              options: {},
              filter: {}
            }
          }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: param is missing or the value is empty or invalid: options'
            )
          end
        end

        response '422', 'rejects options with missing bucket_size param' do
          let(:request_body) {
            {
              options: { irrelevant: 'value' },
              filter: {}
            }
          }

          run_test! do
            expect_error(
              :unprocessable_content,
              'The request could not be understood: param is missing or the value is empty or invalid: bucket_size'
            )
          end
        end
      end
    end
  end
end
