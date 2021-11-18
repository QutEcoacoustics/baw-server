# frozen_string_literal: true

require 'swagger_helper'

# we're using the rswag DLS here instead of our helper methods because the
# download action is not part of our normal CRUD workflow.
describe 'downloader#index', type: :request do
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  with_authorization
  for_model AudioRecording

  path '/audio_recordings/downloader' do
    get 'Gets a templated script which can download original audio files' do
      tags 'downloader'
      produces 'text/plain'

      response '200', 'templated script' do
        run_test!
      end
    end

    post 'Gets a templated script which can download original audio files. Accepts an audio recordings filter object' do
      tags 'downloader'
      produces 'text/plain'

      response '200', 'templated script' do
        run_test!
      end
    end
  end
end
