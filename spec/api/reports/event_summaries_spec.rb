# frozen_string_literal: true

require 'swagger_helper'

describe 'reports', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization

  let(:skip_automatic_description) { true }

  before do
    provenance = create(:provenance, creator: writer_user)

    create(
      :audio_event_using_tag,
      audio_recording:,
      creator: writer_user,
      tag:,
      score: 1,
      provenance:
    )
  end

  def self.response_body_schema
    Api::Schema.standard_array_response(
      {
        type: 'object',
        additionalProperties: false,
        properties: {
          tag_id: Api::Schema.id,
          provenance_id: Api::Schema.id(nullable: true),
          events: {
            type: 'integer',
            description: 'The number of events in the tag and provenance grouping'
          },
          score_mean: {
            type: ['number', 'null'],
            description: 'Mean score, null when summary statistics are unavailable'
          },
          score_stddev: {
            type: ['number', 'null'],
            description: 'Sample standard deviation of scores, null when summary statistics are unavailable'
          },
          score_minimum: {
            type: ['number', 'null'],
            description: 'Minimum score, null when summary statistics are unavailable'
          },
          score_maximum: {
            type: ['number', 'null'],
            description: 'Maximum score, null when summary statistics are unavailable'
          },
          score_histogram: {
            type: ['object', 'null'],
            additionalProperties: false,
            properties: {
              bins: {
                type: 'array',
                items: { type: 'integer' },
                description: 'A 50-bin histogram of in-range event scores for the grouping'
              },
              maximum: {
                type: 'number',
                description: 'The maximum score included in the histogram bins (inclusive). ' \
                             'The provenance maximum is used if set; otherwise, the maximum score in the group is used.'
              },
              minimum: {
                type: 'number',
                description: 'The minimum score included in the histogram bins (inclusive). ' \
                             'The provenance minimum is used if set; otherwise, the minimum score in the group is used.'
              },
              underflow: {
                type: 'integer',
                description: 'The count of events with scores below the histogram minimum'
              },
              overflow: {
                type: 'integer',
                description: 'The count of events with scores above the histogram maximum'
              }
            },
            required: [:bins, :maximum, :minimum, :underflow, :overflow],
            description: 'Score histogram, null when summary statistics are unavailable'
          },
          readOnly: true
        },
        required: [:tag_id, :provenance_id, :events]
      }
    )
  end

  def self.request_body_schema
    Api::Schema.filter_payload(filter: true, sorting: false, paging: false, projection: false)
  end

  path '/reports/event_summaries' do
    post 'Gets event summary statistics per tag and provenance grouping' do
      tags 'reports'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns event summary statistics grouped by tag and provenance.
        The optional `filter` parameter is applied to audio events.
        Results only include audio events the user has reader access to.
      DESCRIPTION

      parameter name: :request_body, in: :body, required: true,
        schema: request_body_schema

      response '200', 'event summaries report retrieved' do
        schema(**response_body_schema)

        let(:request_body) { { filter: {} } }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio events by tag' do
        let(:request_body) do
          {

            filter: { 'tags.id': { eq: tag.id } }
          }
        end

        run_test! do
          expect_at_least_one_item
        end
      end

      response '422', 'rejects paging parameters' do
        let(:request_body) { { paging: { items: 10 } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects sort parameters' do
        let(:request_body) { { sort: { order_by: 'id' } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects projection parameters' do
        let(:request_body) { { projection: { only: [:id] } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end
    end
  end
end
