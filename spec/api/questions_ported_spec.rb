# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/questions_spec.rb.

require 'swagger_helper'

describe 'Questions API (ported)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Question

  which_has_schema(
    type: :object,
    required: [:id, :text, :data, :creator_id, :created_at, :updater_id, :updated_at],
    additionalProperties: false,
    properties: {
      id: { type: :integer },
      text: { type: :string, nullable: true },
      data: { type: :string, nullable: true },
      creator_id: { type: :integer },
      created_at: { type: :string, format: 'date-time' },
      updater_id: { type: :integer, nullable: true },
      updated_at: { type: :string, format: 'date-time', nullable: true }
    }
  )

  let(:question_attributes) { { question: attributes_for(:question, study_ids: [study.id]) } }

  path '/questions' do
    get('list questions') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(question, default_question) }
      end
    end

    post('create question') do
      parameter name: :question_attributes, in: :body, schema: {
        type: :object, required: [:question],
        properties: {
          question: {
            type: :object, required: [:study_ids],
            properties: {
              text: { type: :string }, data: { type: :string },
              study_ids: { type: :array, minItems: 1, items: { type: :integer } }
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

  path '/questions/new' do
    get('new question template') do
      response(200, 'successful') do
        schema(**Api::Schema.standard_single_response(
          type: :object, required: [:text, :data],
          properties: { text: { type: :string, nullable: true }, data: { type: :string, nullable: true } }
        ))
        run_test! { expect(api_result[:data]).to include(text: nil, data: nil) }
      end
    end
  end

  path '/questions/filter' do
    post('filter questions') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(question, default_question) }
      end
    end
  end

  path '/questions/{id}' do
    with_id_route_parameter
    let(:id) { question.id }

    get('show question') do
      response(200, 'successful') do
        schema_for_single
        run_test! { expect_id_matches(question) }
      end
    end

    put('update question') do
      parameter name: :question_attributes, in: :body, schema: {
        type: :object, required: [:question],
        properties: { question: { type: :object, properties: { text: { type: :string } } } }
      }
      let(:question_attributes) { { question: { text: 'Updated question text' } } }

      response(200, 'successful') do
        schema_for_single
        run_test! { expect_id_matches(question) }
      end
    end

    delete('delete question') do
      response(204, 'successful') do
        schema nil
        run_test! { expect_empty_body }
      end
    end
  end
end
