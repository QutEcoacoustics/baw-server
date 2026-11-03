# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/studies_spec.rb.

require 'swagger_helper'

describe 'Studies API (ported)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Study

  # These legacy models do not expose Model.schema or registered component schemas.
  which_has_schema(
    type: :object,
    required: [:id, :name, :dataset_id, :creator_id, :created_at, :updater_id, :updated_at],
    additionalProperties: false,
    properties: {
      id: { type: :integer },
      name: { type: :string, nullable: true },
      dataset_id: { type: :integer },
      creator_id: { type: :integer },
      created_at: { type: :string, format: 'date-time' },
      updater_id: { type: :integer, nullable: true },
      updated_at: { type: :string, format: 'date-time', nullable: true }
    }
  )

  let(:study_attributes) { { study: attributes_for(:study, name: 'New Study name', dataset_id: dataset.id) } }

  path '/studies' do
    get('list studies') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(study, default_study) }
      end
    end

    post('create study') do
      parameter name: :study_attributes, in: :body, schema: {
        type: :object, required: [:study],
        properties: {
          study: {
            type: :object, required: [:dataset_id],
            properties: { name: { type: :string }, dataset_id: { type: :integer } }
          }
        }
      }

      response(201, 'successful') do
        schema_for_single
        run_test! { expect(api_result[:data]).to include(name: 'New Study name') }
      end
    end
  end

  path '/studies/new' do
    get('new study template') do
      response(200, 'successful') do
        schema(**Api::Schema.standard_single_response(
          type: :object, required: [:name], properties: { name: { type: :string, nullable: true } }
        ))
        run_test! { expect(api_result[:data]).to include(name: nil) }
      end
    end
  end

  path '/studies/filter' do
    post('filter studies') do
      response(200, 'successful') do
        schema_for_many
        run_test! { expect_has_ids(study, default_study) }
      end
    end
  end

  path '/studies/{id}' do
    with_id_route_parameter
    let(:id) { study.id }

    get('show study') do
      response(200, 'successful') do
        schema_for_single
        run_test! { expect_id_matches(study) }
      end
    end

    put('update study') do
      parameter name: :study_attributes, in: :body, schema: {
        type: :object, required: [:study],
        properties: { study: { type: :object, properties: { name: { type: :string } } } }
      }
      let(:study_attributes) { { study: { name: 'Updated study name' } } }

      response(200, 'successful') do
        schema_for_single
        run_test! { expect_id_matches(study) }
      end
    end

    delete('delete study') do
      response(204, 'successful') do
        schema nil
        run_test! { expect_empty_body }
      end
    end
  end
end
