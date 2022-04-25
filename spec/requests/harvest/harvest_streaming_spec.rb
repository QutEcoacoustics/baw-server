# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting streaming files' do
  extend WebServerHelper::ExampleGroup
  include HarvestSpecCommon

  describe 'errors' do
    it 'cannot create a new harvest in any state' do
      body = {
        harvest: {
          streaming: true,
          status: :uploading
        }
      }

      post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :unprocessable_entity,
        'The request could not be understood: found unpermitted parameter: :status'
      )
    end

    # execute the following specs in order without resetting state between them
    stepwise 'cannot transition into an error state' do
      step 'can be created' do
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
      end

      [:new_harvest, :metadata_review, :processing, :review].each do |status|
        step "cannot transition from uploading->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end
    end
  end

  describe 'optimal workflow' do
    expose_app_as_web_server

    stepwise 'several files are uploaded' do
      step 'can be created' do
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
      end

      step 'SFTPGO has an upload slot enabled' do
        expect_upload_slot_enabled
      end

      step 'Our harvest endpoint returns login details' do
        expect_filled_in_sftp_login_details
      end

      step 'we can upload a file' do
        upload_file(connnection, Fixtures.audio_file_mono)
      end

      step 'we can observe the webhook has fired' do
        pending
      end

      step 'we can harvest the file' do
        pending
      end

      step 'our report has useful statistics' do
        pending
      end

      step 'we can query audio_recordings for the file based off of the harvest id' do
        pending
      end
    end

    it 'supports uploading multiple files' do
      pending
    end
  end

  describe 'harvest can complete' do
    stepwise 'complete a harvest' do
      step 'create a harvest' do
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
      end

      step 'upload a file' do
        pending
      end

      step 'complete the harvest' do
        pending
      end

      step 'the sftp connection is closed' do
        pending
      end

      step 'our harvest endpoint removes login details' do
        pending
      end

      step 'process the queued harvest item job' do
        pending
      end

      step 'a new recording is available' do
        pending
      end
    end
  end
end
