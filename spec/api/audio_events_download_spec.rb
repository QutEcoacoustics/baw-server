# frozen_string_literal: true

require 'swagger_helper'

describe 'download audio_events', type: :request do
  include_context 'shared_test_helpers'

  context 'with audio_recording route' do
    create_entire_hierarchy
    with_authorization
    for_model AudioEvent

    let(:audio_recording_id) { audio_recording.id }

    path '/audio_recordings/{audio_recording_id}/audio_events/download' do
      with_route_parameter :audio_recording_id

      get('download project audio events') do
        consumes nil
        produces 'text/csv'

        response(200, 'successful') do
          run_test!
        end
      end
    end
  end

  context 'with projects route' do
    create_entire_hierarchy
    with_authorization
    for_model AudioEvent

    let(:project_id) { project.id }
    let(:site_id) { site.id }

    path '/projects/{project_id}/audio_events/download' do
      with_route_parameter :project_id

      get('download project audio events') do
        consumes nil
        produces 'text/csv'

        response(200, 'successful') do
          run_test!
        end
      end
    end

    path '/projects/{project_id}/sites/{site_id}/audio_events/download' do
      with_route_parameter :project_id
      with_route_parameter :site_id

      get('download project audio events') do
        consumes nil
        produces 'text/csv'

        response(200, 'successful') do
          run_test!
        end
      end
    end
  end

  context 'with user_accounts route' do
    create_entire_hierarchy
    with_authorization
    for_model AudioEvent

    let(:user_id) { writer_user.id }

    path '/user_accounts/{user_id}/audio_events/download' do
      with_route_parameter :user_id

      get 'download user audio events' do
        consumes nil
        produces 'text/csv'

        response(200, 'successful') do
          run_test!
        end
      end
    end
  end
end
