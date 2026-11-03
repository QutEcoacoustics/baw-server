# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/responses_spec.rb.

require 'swagger_helper'

describe 'Responses API (ported)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Response

  which_has_schema(
    type: :object,
    required: [:id, :data, :creator_id, :created_at, :study_id, :question_id, :dataset_item_id],
    additionalProperties: false,
    properties: {
      id: { type: :integer },
      data: { type: :string },
      creator_id: { type: :integer },
      created_at: { type: :string, format: 'date-time' },
      study_id: { type: :integer },
      question_id: { type: :integer },
      dataset_item_id: { type: :integer }
    }
  )

  let(:response_attributes) do
    {
      response: attributes_for(
        :response, data: '{"test_name":"test value"}',
        study_id: study.id, question_id: question.id, dataset_item_id: dataset_item.id
      )
    }
  end

  path '/responses' do
    get('list responses') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(user_response, default_user_response) }
      end
    end

    post('create response') do
      parameter name: :response_attributes, in: :body, schema: {
        type: :object, required: [:response],
        properties: {
          response: {
            type: :object, required: [:data, :study_id, :question_id, :dataset_item_id],
            properties: {
              data: { type: :string }, study_id: { type: :integer },
              question_id: { type: :integer }, dataset_item_id: { type: :integer }
            }
          }
        }
      }

      response(201, 'successful') do
        schema_for_single
        run_test!
      end
    end
  end

  path '/responses/new' do
    get('new response template') do
      response(200, 'successful') do
        schema(**Api::Schema.standard_single_response(
          type: :object, required: [:data], properties: { data: { type: :string, nullable: true } }
        ))
        run_test! { expect(api_result[:data]).to include(data: nil) }
      end
    end
  end

  path '/responses/filter' do
    post('filter responses') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(user_response, default_user_response) }
      end
    end
  end

  path '/responses/{id}' do
    with_id_route_parameter
    let(:id) { user_response.id }

    get('show response') do
      response(200, 'successful') do
        schema_for_single
        run_test! { expect_id_matches(user_response) }
      end
    end

    delete('delete response') do
      response(204, 'successful') do
        schema nil
        run_test! { expect_empty_body }
      end
    end
  end
end
