# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  describe 'user expiry' do
    pause_all_jobs
    ignore_pending_jobs

    stepwise 'can transition to metadata_review if an error occurred in :metadata_extraction' do
      step 'create a harvest' do
        create_harvest(streaming: false)
        expect(harvest).to be_uploading
        expect(harvest).to be_batch_harvest
      end

      step 'we are tracking user expiry on the harvest' do
        harvest_expiry = harvest.upload_user_expiry_at
        upload_user = BawWorkers::Config.upload_communicator.get_user(harvest.upload_user)
        sftpgo_expiry = upload_user.expiration_time

        expect(harvest_expiry).to eq sftpgo_expiry
      end

      step '(nil) if we set upload_user_expiry_at to nil' do
        harvest.upload_user_expiry_at = nil
        harvest.save!
      end

      step '(nil) then on GET, the expiry will be renewed' do
        get_harvest

        expected = BawWorkers::UploadService::Communicator::STANDARD_EXPIRY.from_now

        expect(harvest.upload_user_expiry_at).not_to be_nil
        expect(harvest.upload_user_expiry_at).to be_within(3.seconds).of(expected)
      end

      step '(nil) and the same value will be reflected in sftpgo' do
        expect_same_value_in_sftpgo(harvest)
      end

      step '(expiry) if we set upload_user_expiry_at to 50% of the expiry time' do
        too_short = ((BawWorkers::UploadService::Communicator::STANDARD_EXPIRY / 2) - 1.minute).from_now
        harvest.upload_user_expiry_at = too_short
        harvest.save!
      end

      step '(expiry) then on GET, the expiry will be renewed' do
        get_harvest

        expected = BawWorkers::UploadService::Communicator::STANDARD_EXPIRY.from_now

        expect(harvest.upload_user_expiry_at).not_to be_nil
        expect(harvest.upload_user_expiry_at).to be_within(3.seconds).of(expected)
      end

      step '(expiry) and the same value will be reflected in sftpgo' do
        expect_same_value_in_sftpgo(harvest)
      end

      step '(complete) after transitioning to :complete' do
        transition_harvest(:complete)
        expect_success
      end

      step '(complete) we expect upload_user_expiry_at to be nil' do
        expect(harvest.upload_user_expiry_at).to be_nil
      end

      step '(complete) and on GET, the expiry will NOT be renewed' do
        get_harvest
        expect_success

        expect(harvest.upload_user_expiry_at).to be_nil
      end
    end

    def expect_same_value_in_sftpgo(harvest)
      harvest_expiry = harvest.upload_user_expiry_at
      upload_user = BawWorkers::Config.upload_communicator.get_user(harvest.upload_user)
      sftpgo_expiry = upload_user.expiration_time

      expect(harvest_expiry).to eq sftpgo_expiry
    end

    it 'will not fail the GET request if something goes wrong' do
      create_harvest(streaming: false)
      expect(harvest).to be_uploading
      expect(harvest).to be_batch_harvest

      harvest.upload_user_expiry_at = nil
      harvest.save!

      # ensure the request fails
      stub_request(
        :put,
        %r{#{Settings.upload_service.admin_host}:8080/api/v2/users/.*}
      ).to_timeout

      ActionMailer::Base.deliveries.clear

      get_harvest

      expect_success

      # value was unchanged
      expect(harvest.upload_user_expiry_at).to be_nil

      sleep 1

      # error email was sent
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries[0]
      expect(email.body.encoded).to include("Failed to refresh upload user expiry for harvest #{harvest.id}")
    end
  end
end
