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
          **Api::Schema.bucket,
          tags: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              properties: {
                tag_id: { type: Api::Schema.id },
                events: { type: 'integer', description: 'The number of events with the given tag in the bucket' }
              }
            }
          },
          readOnly: true
        },
        required: [:bucket, :tags]
      }
    )
  end

  def self.request_body_schema
    Api::Schema.filter_payload(
      filter: true, sorting: false, paging: false, projection: false, options: Api::Schema.report_options
    )
  end

  path '/reports/tag_frequency' do
    post 'Gets event frequency per tag across time buckets' do
      tags 'reports'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns event frequency per tag across time buckets.
        The `options` parameter specifies the bucket size (day, week, month, or year).
        The optional `filter` parameter is applied to audio events.
        Results only include audio events the user has reader access to.
      DESCRIPTION

      parameter name: :request_body, in: :body, required: true,
        schema: request_body_schema

      response '200', 'tag frequency report retrieved' do
        schema(**response_body_schema)

        let(:request_body) { { options: { bucket_size: 'day' }, filter: {} } }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio events by tag' do
        let(:request_body) do
          {
            options: { bucket_size: 'day' },
            filter: { 'tags.id': { eq: tag.id } }
          }
        end

        run_test! do
          expect_at_least_one_item
        end
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
