# frozen_string_literal: true

require 'swagger_helper'

describe 'audio_event_imports', type: :request do
  create_entire_hierarchy

  let!(:audio_event_import) { create(:audio_event_import) }

  sends_json_and_expects_json
  with_authorization
  for_model AudioEventImport
  which_has_schema ref(:audio_event_import)

  path '/audio_event_imports/filter' do
    post('filter audio_event_import') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/audio_event_imports' do
    get('list audio_event_imports') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create audio_event_import') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/audio_event_imports/new' do
    get('new audio_event_import') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/audio_event_imports/{id}' do
    with_id_route_parameter
    let(:id) { audio_event_import.id }

    get('show audio_event_import') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(audio_event_import)
        end
      end
    end

    patch('update audio_event_import') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(audio_event_import)
        end
      end
    end

    put('update audio_event_import') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(audio_event_import)
        end
      end
    end

    delete('delete audio_event_import') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
