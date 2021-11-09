# frozen_string_literal: true

require 'swagger_helper'

describe 'audio recordings (nested)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AudioRecording
  which_has_schema ref(:audio_recording)

  let(:project_id) { project.id }
  let(:site_id) { site.id }

  path '/projects/{project_id}/sites/{site_id}/audio_recordings/filter' do
    with_route_parameter(:project_id)
    with_route_parameter(:site_id)

    # not defined for nested routes
    #post('filter audio recording') do
    #  response(200, 'successful') do
    #    schema_for_many
    #    run_test! do
    #      expect_at_least_one_item
    #    end
    #  end
    #end
  end

  path '/projects/{project_id}/sites/{site_id}/audio_recordings' do
    with_route_parameter(:project_id)
    with_route_parameter(:site_id)

    # not defined for nested routes
    # get('list audio recordings') do
    #   response(200, 'successful') do
    #     schema_for_many
    #     run_test! do
    #       expect_at_least_one_item
    #     end
    #   end
    # end

    post('create audio recordings') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/projects/{project_id}/sites/{site_id}/audio_recordings/new' do
    with_route_parameter(:project_id)
    with_route_parameter(:site_id)

    get('new audio recordings') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{project_id}/sites/{site_id}/audio_recordings/{id}' do
    with_route_parameter(:project_id)
    with_route_parameter(:site_id)
    with_id_route_parameter
    let(:id) { audio_recording.id }

    # not defined for nested routes
    # get('show audio recordings') do
    #   response(200, 'successful') do
    #     schema_for_single
    #     run_test! do
    #       expect_id_matches(audio_recording)
    #     end
    #   end
    # end

    # not defined for nested routes
    # patch('update audio recordings') do
    #   model_sent_as_parameter_in_body
    #   response(200, 'successful') do
    #     schema_for_single
    #     auto_send_model
    #     run_test! do
    #       expect_id_matches(audio_recording)
    #     end
    #   end
    # end

    # not defined for nested routes
    # put('update audio recordings') do
    #   model_sent_as_parameter_in_body
    #   response(200, 'successful') do
    #     schema_for_single
    #     auto_send_model
    #     run_test! do
    #       expect_id_matches(audio_recording)
    #     end
    #   end
    # end

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
