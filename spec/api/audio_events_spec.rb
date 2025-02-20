# frozen_string_literal: true

require 'swagger_helper'
describe 'audio_events (shallow)' do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AudioEvent
  which_has_schema ref(:audio_event)
  let(:audio_recording_id) { audio_recording.id }

  path '/audio_events/filter' do
    post('filter audio_event') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end
end

describe 'audio_events (nested)' do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AudioEvent
  which_has_schema ref(:audio_event)
  let(:audio_recording_id) { audio_recording.id }

  path '/audio_recordings/{audio_recording_id}/audio_events/filter' do
    with_route_parameter(:audio_recording_id) { audio_recording_id }

    post('filter audio_events') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/audio_recordings/{audio_recording_id}/audio_events' do
    with_route_parameter(:audio_recording_id) { audio_recording_id }

    get('list audio_events') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create audio_event') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/audio_recordings/{audio_recording_id}/audio_events/new' do
    with_route_parameter(:audio_recording_id) { audio_recording_id }

    get('new audio_event') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/audio_recordings/{audio_recording_id}/audio_events/{id}' do
    with_route_parameter(:audio_recording_id) { audio_recording_id }
    with_id_route_parameter
    let(:id) { audio_event.id }

    get('show audio_event') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(audio_event)
        end
      end
    end

    patch('update audio_event') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end

    put('update audio_event') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end

    delete('delete audio_event') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
