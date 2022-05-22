# frozen_string_literal: true

module UploadServiceSteps
  include Dry::Monads[:result]

  def upload_host
    @upload_host = Settings.upload_service.host
    @upload_host
  end

  def expect_configured_service
    expect(BawWorkers::Config.upload_communicator).to be_a(BawWorkers::UploadService::Communicator)
  end

  def delete_all_upload_users
    deleted = BawWorkers::Config.upload_communicator.delete_all_users
    expect(deleted).to all(eq('User deleted'))
  end

  def get_all_upload_users
    BawWorkers::Config.upload_communicator.get_all_users
  end

  def ensure_no_upload_users
    delete_all_upload_users
    users = get_all_upload_users
    expect(users).to have(0).items
  end

  def create_upload_user(username, password)
    @username = username
    @password = password
    @user = BawWorkers::Config.upload_communicator.create_upload_user(
      username:,
      password:,
      home_dir: Pathname(harvest_to_do_path) / @username
    )
    @connection = {
      username:,
      password:,
      url: "sftp://#{upload_host}:2022"
    }
  end

  def set_upload_user_ableness(enabled:)
    result = BawWorkers::Config.upload_communicator.set_user_status(@user, enabled:)

    expect(result).to eq(SftpgoClient::ApiResponse.new(message: 'User updated'))
  end

  def expect_ableness(enabled:)
    @user = BawWorkers::Config.upload_communicator.get_user(@user)
    expect(@user.status).to eq(enabled ? 1 : 0)
  end

  def run_curl(command, should_work:)
    # upload with curl since container doesn't have scp/sftp installed and it is
    # not worth adding the tools for one test

    output_and_error = nil
    status = nil
    logger.measure_info('Executing timeout with curl', command:) do
      # libssh2 (which curl uses) has some kind of bug that results in a connection
      # hanging indefinitely if the server closes the connection abruptly (e.g
      # in the case where auth fails).
      # Use the unix timeout command to force a shutdown.

      # need to use Open3 here; using Kernel.`` will throw errors when web_server_helper is also
      # used in specs. See spec/unit/spec/support/web_server_helper_spec.rb for examples
      # of things that do and do not work.
      output_and_error, status = Open3.capture2e("/usr/bin/timeout 6 #{command} -v")
    rescue StandardError => e
      logger.error('error whilst running curl', e)
      raise
    end

    message = lambda {
      not_equal = should_work ? '' : 'not equal to '
      "Expected exit code #{not_equal}0, got #{status.exitstatus}.\nCommand: #{command}\nOutput & error:\n#{output_and_error}"
    }
    if should_work
      expect(status.exitstatus).to be_zero, message
    else
      expect(status.exitstatus).not_to be_zero, message
    end

    output_and_error
  end

  def upload_file(connection, source, to: nil, should_work: true)
    connection => {url:, username:, password:}

    raise 'to must start with a slash' unless to.nil? || to.start_with?('/')

    run_curl(
      %(curl --insecure --user "#{username}:#{password}" -T #{source} -k "#{url}#{to}" --ftp-create-dirs),
      should_work:
    )
  end

  def rename_remote_file(connection, from:, to:, should_work: true)
    connection => {url:, username:, password:}

    command = %(curl --user "#{username}:#{password}" -Q '-RENAME "#{from}" "#{to}"' "#{url}" --insecure)
    run_curl(command, should_work:)
  end

  def create_remote_directory(connection, remote_path, should_work: true)
    connection => {url:, username:, password:}

    command = %(curl --user "#{username}:#{password}" -Q '-MKDIR "#{remote_path}"' "#{url}" --insecure)
    run_curl(command, should_work:)
  end

  def delete_remote_file(connection, remote_path)
    connection => {url:, username:, password:}
    command = %(curl --user "#{username}:#{password}" -Q '-RM "#{remote_path}"' "#{url}" --insecure)
    run_curl(command, should_work: true)
  end

  def delete_remote_directory(connection, remote_path)
    connection => {url:, username:, password:}
    command = %(curl --user "#{username}:#{password}" -Q '-RMDIR "#{remote_path}"' "#{url}" --insecure)
    run_curl(command, should_work: true)
  end

  def recursive_delete_remote_files(connection, local_dir, _remote_dir)
    connection => {url:, username:, password:}

    # cheating a bit here: instead of simulating a recursive scan through curl,
    # we're instead doing the scan on the shared storage and just makeing
    # sure the delete parts work
    local_dir.glob('**/*.*') do |file_path|
      remote_path = file_path.relative_path_from(local_dir)

      delete_remote_file(connection, remote_path)

      expect(file_path).not_to exist
    end

    local_dir.glob('**/*/').sort_by { |x| -x.to_s.count('/') }.each do |dir_path|
      remote_path = dir_path.relative_path_from(local_dir)

      delete_remote_directory(connection, remote_path)

      expect(dir_path).not_to exist
    end
  end

  def self.included(example_group)
    example_group.after(:all) do
      delete_all_upload_users
    end
  end
end
