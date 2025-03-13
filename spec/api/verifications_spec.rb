# frozen_string_literal: true

require 'swagger_helper'

describe 'verifications' do
  describe 'shallow', type: :request do
    create_entire_hierarchy

    sends_json_and_expects_json
    with_authorization
    for_model Verification
    which_has_schema ref(:verification)

    path '/verifications/filter' do
      post('filter verification') do
        response(200, 'successful') do
          schema_for_many
          run_test! do
            expect_at_least_one_item
          end
        end
      end
    end

    path '/verifications' do
      get('list verifications') do
        response(200, 'successful') do
          schema_for_many
          run_test! do
            expect_at_least_one_item
          end
        end
      end

      post('create verification') do
        model_sent_as_parameter_in_body
        response(201, 'successful') do
          schema_for_single
          auto_send_model
          run_test!
        end
      end

      put('create or update verification') do
        model_sent_as_parameter_in_body

        response(201, 'successful') do
          schema_for_single
          auto_send_model
          run_test!
        end

        response(200, 'successful') do
          schema_for_single

          let(:existing_verification) {
            create(:verification, audio_event:, tag:, creator: admin_user)
          }

          send_model do
            {
              'verification' => {
                audio_event_id: existing_verification.audio_event_id,
                tag_id: existing_verification.tag_id,
                confirmed: Verification::CONFIRMATION_FALSE
              }
            }
          end
          run_test! do
            expect_id_matches(existing_verification)
          end
        end
      end
    end

    path '/verifications/new' do
      get('new verification') do
        response(200, 'successful') do
          run_test!
        end
      end
    end

    path '/verifications/{id}' do
      with_id_route_parameter
      let(:id) { verification.id }

      get('show verification') do
        response(200, 'successful') do
          schema_for_single
          run_test! do
            expect_id_matches(verification)
          end
        end
      end

      patch('update verification') do
        model_sent_as_parameter_in_body
        response(200, 'successful') do
          schema_for_single
          send_model do
            {
              'verification' => {
                confirmed: Verification::CONFIRMATION_FALSE
              }
            }
          end
          run_test! do
            expect_id_matches(verification)
          end
        end
      end

      put('update verification') do
        model_sent_as_parameter_in_body
        response(200, 'successful') do
          schema_for_single
          send_model do
            {
              'verification' => {
                confirmed: Verification::CONFIRMATION_FALSE
              }
            }
          end
          run_test! do
            expect_id_matches(verification)
          end
        end
      end

      delete('delete verification') do
        response(204, 'successful') do
          schema nil
          run_test! do
            expect_empty_body
          end
        end
      end
    end
  end

  describe 'nested', type: :request do
    create_entire_hierarchy

    sends_json_and_expects_json
    with_authorization
    for_model Verification
    which_has_schema ref(:verification)

    let(:audio_recording_id) { audio_recording.id }
    let(:audio_event_id) { audio_event.id }

    path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/verifications/filter' do
      with_route_parameter(:audio_recording_id) { audio_recording_id }
      with_route_parameter(:audio_event_id) { audio_event_id }

      post('filter verification') do
        response(200, 'successful') do
          schema_for_many
          run_test! do
            expect_at_least_one_item
          end
        end
      end
    end

    path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/verifications' do
      with_route_parameter(:audio_recording_id) { audio_recording_id }
      with_route_parameter(:audio_event_id) { audio_event_id }

      get('list verifications') do
        response(200, 'successful') do
          schema_for_many
          run_test! do
            expect_at_least_one_item
          end
        end
      end
    end

    path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/verifications/{id}' do
      with_route_parameter(:audio_recording_id) { audio_recording_id }
      with_route_parameter(:audio_event_id) { audio_event_id }

      with_id_route_parameter
      let(:id) { verification.id }

      get('show verification') do
        response(200, 'successful') do
          schema_for_single
          run_test! do
            expect_id_matches(verification)
          end
        end
      end
    end
  end
end
