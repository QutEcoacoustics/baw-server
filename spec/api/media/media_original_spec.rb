# frozen_string_literal: true

require 'swagger_helper'

# we're using the rswag DLS here instead of our helper methods because the
# download action is not part of our normal CRUD workflow.
describe 'media#original', type: :request do
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  let!(:test_file) {
    link_original_audio(
      target: Fixtures.audio_file_mono,
      uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date,
      original_format: 'mp3'
    )
  }

  after do
    test_file.unlink
  end

  with_authorization
  for_model AudioRecording

  path '/audio_recordings/{id}/original' do
    get 'Downloads an original audio file' do
      tags 'AudioRecordings', 'Media'

      parameter name: :id, in: :path, type: :string, description: 'ID of the audio recording'

      response '200', 'original audio file' do
        produces 'audio/ogg'
        let(:id) { audio_recording.id }

        run_test!
      end

      response '404', 'not found' do
        let(:id) { '123456' }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:id) { audio_recording.id }
        let(:Authorization) { anonymous_token }
        run_test!
      end
    end

    head 'Gets HTTP headers for an original audio file' do
      tags 'AudioRecordings', 'Media'
      produces 'audio/ogg'

      parameter name: :id, in: :path, type: :string, description: 'ID of the audio recording'

      response '200', 'original audio file' do
        produces 'audio/ogg'
        let(:id) { audio_recording.id }

        run_test!
      end

      response '404', 'not found' do
        let(:id) { '123456' }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:id) { audio_recording.id }

        let(:Authorization) { anonymous_token }
        run_test!
      end
    end
  end
end
