# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/dataset_items_spec.rb.

require 'swagger_helper'

describe 'Dataset items (ported acceptance cases)', type: :request do
  create_audio_recordings_hierarchy
  prepare_dataset
  prepare_dataset_item

  sends_json_and_expects_json
  with_authorization
  for_model DatasetItem

  # DatasetItem has no registered model schema; keep this contract local to the port.
  which_has_schema(
    type: :object,
    additionalProperties: false,
    properties: {
      id: { type: :integer, readOnly: true },
      dataset_id: { type: :integer },
      audio_recording_id: { type: :integer },
      start_time_seconds: { type: :number },
      end_time_seconds: { type: :number },
      order: { type: :number, nullable: true },
      creator_id: { type: :integer, readOnly: true },
      created_at: { type: :string, format: :'date-time', readOnly: true }
    },
    required: [
      :id, :dataset_id, :audio_recording_id, :start_time_seconds, :end_time_seconds, :order, :creator_id, :created_at
    ]
  )

  let(:dataset_id) { dataset.id }
  let(:id) { dataset_item.id }

  path '/datasets/{dataset_id}/items' do
    with_route_parameter :dataset_id

    get('list dataset items') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(dataset_item)
        end
      end
    end

    post('create dataset item') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          { dataset_item: { audio_recording_id: audio_recording.id, start_time_seconds: 1, end_time_seconds: 234 } }
        end
        run_test! do
          expect(api_result[:data]).to include(dataset_id: dataset.id, end_time_seconds: 234.0)
        end
      end
    end
  end

  path '/datasets/{dataset_id}/items/new' do
    with_route_parameter :dataset_id

    get('new dataset item') do
      response(200, 'successful') do
        schema(**Api::Schema.standard_single_response(
          type: :object,
          additionalProperties: false,
          properties: {
            audio_recording_id: { type: :integer, nullable: true },
            start_time_seconds: { type: :number, nullable: true },
            end_time_seconds: { type: :number, nullable: true },
            order: { type: :number, nullable: true }
          },
          required: [:audio_recording_id, :start_time_seconds, :end_time_seconds, :order]
        ))
        run_test!
      end
    end
  end

  path '/datasets/{dataset_id}/items/{id}' do
    with_route_parameter :dataset_id
    with_id_route_parameter

    get('show dataset item') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(dataset_item)
        end
      end
    end

    put('update dataset item') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          { dataset_item: { end_time_seconds: 234 } }
        end
        run_test! do
          expect_id_matches(dataset_item)
          expect(api_result[:data][:end_time_seconds]).to eq(234.0)
        end
      end
    end
  end

  path '/dataset_items/filter' do
    post('filter dataset items') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(dataset_item, default_dataset_item)
        end
      end
    end
  end

  path '/datasets/{dataset_id}/dataset_items/filter' do
    with_route_parameter :dataset_id

    post('filter items in a dataset') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(dataset_item)
        end
      end
    end
  end

  path '/datasets/{dataset_id}/dataset_items/next_for_me' do
    with_route_parameter :dataset_id

    get('list next dataset items for the current user') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(dataset_item)
        end
      end
    end
  end
end
