# frozen_string_literal: true

require 'support/shared_test_helpers'
require_relative(Rails.root / 'spec/lib/gems/baw_workers/upload_service/upload_service_steps')

module HarvestSpecCommon
  # @!parse
  #   include RequestSpecHelpers::Example
  #   include UploadServiceSteps

  def self.included(other)
    other.prepare_users
    other.prepare_project

    other.include_context 'shared_test_helpers'
    other.include UploadServiceSteps

    other.before do
      BawWorkers::Config.upload_communicator.delete_all_users
      clear_harvester_to_do
    end
  end

  ALL_STATES = Harvest.aasm.states.map(&:name)

  def harvest
    return nil if @harvest_id.nil?

    @harvest ||= Harvest.find(@harvest_id)
  end

  def connnection
    {
      username: harvest&.upload_user,
      password: harvest&.upload_password,
      url: harvest&.upload_url
    }
  end

  # @return [BawWorkers::UploadService::Communicator]
  def upload_communicator
    BawWorkers::Config.upload_communicator
  end

  def create_harvest(streaming: false)
    body = {
      harvest: {
        streaming:
      }
    }

    post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

    @harvest_id = (api_result[:data][:id]) if response.response_code == 201
  end

  def transition_harvest(new_status)
    body = {
      harvest: {
        status: new_status
      }
    }

    patch "/projects/#{project.id}/harvests/#{@harvest.id}", params: body, **api_with_body_headers(owner_token)

    @harvest.reload
  end

  def get_harvest
    get "/projects/#{project.id}/harvests/#{@harvest.id}", **api_headers(owner_token)

    expect_success

    @harvest.reload
  end

  def expect_transition_error(new_status)
    expect_error(
      :unprocessable_entity,
      match(/The request could not be understood: Cannot transition from .* to #{new_status}, \d+ allowed transitions found/),
      nil
    )
  end

  def expect_transition_not_allowed(_new_status)
    expect_error(
      :method_not_allowed,
      match(/The method received the request is known by the server but not supported by the target resource: Cannot update a harvest while it is .*/),
      nil
    )
  end

  def expect_upload_slot_enabled
    name = @harvest.upload_user
    user = upload_communicator.get_user(name)
    expect(user).not_to be_nil
    expect(user.username).to eq(name)
    expect(user.status).to eq SftpgoClient::User::USER_STATUS_ENABLED
    expect(user.home_dir).to eq @harvest.upload_directory.to_s
  end

  def expect_filled_in_sftp_login_details
    get_harvest
    expect_success
    expect(api_data).to match(a_hash_including(
      upload_user: @harvest.creator.safe_user_name,
      upload_password: an_instance_of(String).and(match(/\w{24}/)),
      upload_url: "sftp://#{Settings.upload_service.host}:#{Settings.upload_service.sftp_port}"
    ))
  end
end
