# frozen_string_literal: true

module UploadServiceSteps
  include Dry::Monads[:result]

  step 'the upload service is configured' do
    expect(BawWorkers::Config.upload_communicator).to be_a(BawWorkers::UploadService::Communicator)
  end

  step 'there are no upload users' do
    send 'we delete all users'
    send 'we query for users'
    send 'we find :count users', 0
  end

  step 'service not available' do
    stub_request(:get, 'upload:8080/api/v1/providerstatus')
      .to_return(body: 'error message', status: 500)
  end

  step 'we check service status' do
    @service_status = BawWorkers::Config.upload_communicator.service_status
  end

  step 'it should be good' do
    expect(@service_status).to eq(Success(SftpgoClient::ApiResponse.new(
                                            message: 'Alive'
                                          )))
  end

  step 'it should be bad' do
    expect(@service_status).to be_failure
    expect(@service_status.failure.to_s).to match(/error message/)
  end

  step 'version info is fetched' do
    @version_info = BawWorkers::Config.upload_communicator.server_version
  end

  step 'it contains the version' do
    expect(@version_info).to be_success
    expect(@version_info.value!).to match(a_hash_including({
      version: /\d+\.\d+\.\d+/
    }))
  end

  step 'the users:' do |table|
    @users = table.rows.map { |(username, password)|
      BawWorkers::Config.upload_communicator.create_upload_user(username: username, password: password)
    }
  end

  step 'we query for users' do
    @found_users = BawWorkers::Config.upload_communicator.get_all_users
  end

  step 'we should find those same users' do
    expect(@found_users).to include(*@users)
  end

  step 'we delete all users' do
    deleted = BawWorkers::Config.upload_communicator.delete_all_users
    expect(deleted).to all(eq('User deleted'))
  end

  step 'we find :count users' do |count|
    expect(@found_users).to have(count).items
  end

  step 'I create a user named :username with the password :password' do |username, password|
    @username = username
    @password = password
    @user = BawWorkers::Config.upload_communicator.create_upload_user(
      username: username,
      password: password
    )
  end

  step 'I :on_off the user' do |enabled|
    BawWorkers::Config.upload_communicator.set_user_status(@user, enabled: enabled)
  end

  step 'the user should expire in 7 days' do
    expect(@user.expiration_date).to be_within(60_000).of((Time.now + 7.days).to_i * 1000)
  end

  step 'I :should upload the :file file' do |should, file|
    @upload_path = Fixtures.send(file.to_sym)
    # upload with curl since container doesn't have scp/sftp installed and it is
    # not worth adding the tools for one test
    `curl --user "#{@username}:#{@password}" -T #{@upload_path} -k "sftp://upload:2022"`

    if should
      expect($CHILD_STATUS.exitstatus).to be_zero
    else
      expect($CHILD_STATUS.exitstatus).to_not be_zero
    end
  end

  step 'it should exist in the harvester directory, in the user directory' do
    #tmp/_harvester_to_do_path/harvest_1/test-audio-mono.ogg
    expected = Pathname(harvest_to_do_path) / @username / @upload_path.basename
    expect(File).to exist(expected)
  end

  step 'I upload:' do |table|
    @users = table.rows.map { |(file, to, expected)|
      send_path = Fixtures.send(file.to_sym)
      `curl --user "#{@username}:#{@password}" -T #{send_path} -k "sftp://upload:2022#{to}" --ftp-create-dirs`

      expect($CHILD_STATUS.exitstatus).to be_zero

      expected_path = Pathname(harvest_to_do_path) / @username / expected / send_path.basename
      expect(File).to exist(expected_path)
    }
  end

  step 'I delete all the files' do
    user_dir = Pathname(harvest_to_do_path) / @username
    user_dir.glob('**/*.*') do |file_path|
      remote_path = file_path.relative_path_from(user_dir)
      command = %(curl --user "#{@username}:#{@password}" -Q '-RM "#{remote_path}"' "sftp://upload:2022" --insecure)
      `#{command}`

      expect($CHILD_STATUS.exitstatus).to be_zero
      expect(file_path).to_not exist
    end

    user_dir.glob('**/*/').sort_by { |x| -x.to_s.count('/') }.each do |dir_path|
      remote_path = dir_path.relative_path_from(user_dir)
      command = %(curl --user "#{@username}:#{@password}" -Q '-RMDIR "#{remote_path}"' "sftp://upload:2022" --insecure)
      `#{command}`

      expect($CHILD_STATUS.exitstatus).to be_zero
      expect(dir_path).to_not exist
    end
  end

  def self.included(example_group)
    example_group.after(:all) do
      BawWorkers::Config.upload_communicator.delete_all_users
    end
  end
end
