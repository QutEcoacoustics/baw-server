# frozen_string_literal: true

require 'swagger_helper'

describe 'audio recordings', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AudioRecording
  which_has_schema ref(:audio_recording)

  path '/audio_recordings/filter' do
    post('filter audio recording') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/audio_recordings' do
    get('list audio recordings') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    # post not defined on shallow route
    # post('create audio recordings') do
    #   model_sent_as_parameter_in_body
    #   response(201, 'successful') do
    #     schema_for_single
    #     auto_send_model
    #     run_test!
    #   end
    # end
  end

  path '/audio_recordings/new' do
    get('new audio recordings') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/audio_recordings/{id}' do
    with_id_route_parameter
    let(:id) { audio_recording.id }

    get('show audio recordings') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(audio_recording)
        end
      end
    end

    patch('update audio recordings') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          {
            'audio_recording' => {
              duration_seconds: 66
            }
          }
        end
        run_test! do
          expect_id_matches(audio_recording)
        end
      end
    end

    put('update audio recordings') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          {
            'audio_recording' => {
              duration_seconds: 66
            }
          }
        end
        run_test! do
          expect_id_matches(audio_recording)
        end
      end
    end

    # there is no #delete for audio recordings
    # delete('delete audio recordings') do
    #   response(204, 'successful') do
    #     schema nil
    #     run_test! do
    #       expect_empty_body
    #     end
    #   end
    # end
  end
end
