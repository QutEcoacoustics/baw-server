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
    other.prepare_region
    other.prepare_site

    other.include_context 'shared_test_helpers'
    other.include UploadServiceSteps
    other.watch_controller(Internal::SftpgoController)

    other.before do
      BawWorkers::Config.upload_communicator.delete_all_users
      clear_harvester_to_do
    end
  end

  ALL_STATES = Harvest.aasm.states.map(&:name)

  # @return [Harvest,nil]
  def harvest
    return nil if @harvest_id.nil?

    @harvest ||= Harvest.find(@harvest_id)
  end

  def connection
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

    patch "/projects/#{project.id}/harvests/#{harvest.id}", params: body, **api_with_body_headers(owner_token)

    harvest.reload
  end

  def add_mapping(mapping)
    body = {
      harvest: {
        mappings: harvest.mappings + [mapping]
      }
    }

    patch "/projects/#{project.id}/harvests/#{harvest.id}", params: body, **api_with_body_headers(owner_token)

    harvest.reload
  end

  def get_harvest
    get "/projects/#{project.id}/harvests/#{harvest.id}", **api_headers(owner_token)

    expect_success

    harvest.reload
  end

  def get_audio_recordings_for_harvest
    filter = {
      filter: {
        'harvests.id': { eq: harvest.id }
      }
    }

    post '/audio_recordings/filter', params: filter, **api_with_body_headers(owner_token)

    expect_success

    api_data
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
    name = harvest.upload_user
    user = upload_communicator.get_user(name)
    expect(user).not_to be_nil
    expect(user.username).to eq(name)
    expect(user.status).to eq SftpgoClient::User::USER_STATUS_ENABLED
    expect(user.home_dir).to eq harvest.upload_directory.to_s
  end

  def expect_upload_slot_disabled
    name = harvest.upload_user
    user = upload_communicator.get_user(name)
    expect(user).not_to be_nil
    expect(user.username).to eq(name)
    expect(user.status).to eq SftpgoClient::User::USER_STATUS_DISABLED
    expect(user.home_dir).to eq harvest.upload_directory.to_s
  end

  def expect_upload_slot_deleted
    # we can't check for a username that no longer exists
    # but in these tests we're only working with one user at a time
    # so this test works
    expect(upload_communicator.get_all_users).to be_empty
  end

  def expect_filled_in_sftp_login_details
    get_harvest
    expect(api_data).to match(a_hash_including(
      upload_user: "#{harvest.creator.safe_user_name}_#{harvest.id}",
      upload_password: an_instance_of(String).and(match(/\w{24}/)),
      upload_url: "sftp://#{Settings.upload_service.public_host}:#{Settings.upload_service.sftp_port}"
    ))
  end

  def expect_empty_sftp_login_details
    get_harvest
    expect(api_data).to match(a_hash_including(
      upload_user: nil,
      upload_password: nil,
      upload_url: "sftp://#{Settings.upload_service.public_host}:#{Settings.upload_service.sftp_port}"
    ))
  end

  def expect_pre_filled_mappings
    get_harvest
    expected_dir_name = harvest.streaming_harvest? ? site.id.to_s : site.unique_safe_name

    expect(api_data).to match(a_hash_including({
      mappings: [
        {
          path: expected_dir_name,
          site_id: site.id,
          utc_offset: nil,
          recursive: true
        }
      ]
    }))

    expect(harvest.upload_directory / expected_dir_name).to be_exist
  end

  def expect_report_stats(
    items_total: 0,
    items_size_bytes: 0,
    items_duration_seconds: 0,
    items_new: 0,
    items_metadata_gathered: 0,
    items_completed: 0,
    items_failed: 0,
    items_errored: 0,
    items_invalid_fixable: 0,
    items_invalid_not_fixable: 0
  )
    report = api_data[:report]

    report[:latest_activity_at] = Time.parse(report[:latest_activity_at])

    # seconds
    expected_speed = 90

    aggregate_failures do
      expect(report).to match(a_hash_including(
        items_total:,
        items_size_bytes:,
        items_duration_seconds:,
        items_new:,
        items_metadata_gathered:,
        items_completed:,
        items_failed:,
        items_errored:,
        items_invalid_fixable:,
        items_invalid_not_fixable:,
        latest_activity_at: be_within(expected_speed.seconds).of(Time.now.utc),
        run_time_seconds: an_instance_of(Float).and(be < expected_speed)
      ))
    end
  end

  # hooks are asynchronous processes that are external to our system.
  # we can't just execute tests in sequentially and expect everything to keep up,
  # we have to wait for external services to complete their API calls to us
  def wait_for_webhook(goal: 1)
    wait_for_action_invocation(Internal::SftpgoController, :hook, goal:)
  end

  def reset_webhook_count
    reset_controller_invocation_count(Internal::SftpgoController, :hook)
  end
end
