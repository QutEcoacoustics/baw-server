# frozen_string_literal: true

describe PBS::SSH do
  # make all instance methods public for testing1
  PBS::SSH.class_eval do
    public(*private_instance_methods(false))
  end

  before do
    stub_const('TestClass', Class.new do
      include PBS::SSH

      def initialize
        @settings = Settings.batch_analysis
      end
    end)
  end
  # @!parse
  #   class TestClass
  #     include PBS::SSH
  #   end

  # @!attribute [r] ssh
  #   @return [TestClass]
  let(:ssh) {
    TestClass.new
  }

  it 'can execute an command' do
    status, stdout, stderr = ssh.execute('echo "hello world"')

    aggregate_failures do
      expect(status).to eq 0
      expect(stdout).to eq "hello world\n"
      expect(stderr).to eq ''
    end
  end

  it 'can fail' do
    status, stdout, stderr = ssh.execute('echo "hello world" && exit 1')

    aggregate_failures do
      expect(status).to eq 1
      expect(stdout).to eq "hello world\n"
      expect(stderr).to eq ''
    end
  end

  it 'can write to stderr' do
    status, stdout, stderr = ssh.execute('echo "hello world" && (echo "hello error" >&2)')

    aggregate_failures do
      expect(status).to eq 0
      expect(stdout).to eq "hello world\n"
      expect(stderr).to eq "hello error\n"
    end
  end

  it 'sets the TZ and LANG environment variables' do
    status, stdout, = ssh.execute('env')

    aggregate_failures do
      expect(status).to eq 0
      expect(stdout).to include('TZ=UTC')
      expect(stdout).to include('LANG=en_US.UTF-8')
    end
  end

  context 'with our method of setting environment variables we are robust' do
    example 'command combinations' do
      status, stdout, = ssh.execute('echo "hello" && env')

      aggregate_failures do
        expect(status).to eq 0
        expect(stdout).to include('TZ=UTC')
        expect(stdout).to include('LANG=en_US.UTF-8')
      end
    end

    example 'command termination' do
      status, stdout, = ssh.execute('echo "hello"; env')

      aggregate_failures do
        expect(status).to eq 0
        expect(stdout).to include('TZ=UTC')
        expect(stdout).to include('LANG=en_US.UTF-8')
      end
    end
  end

  it 'can upload a file' do
    path = Pathname('hello.txt')

    ssh.remote_delete(path)
    expect(ssh.remote_exist?(path)).to be false

    io = StringIO.new('Hello World')

    result = ssh.upload_file(io, destination: path)
    expect(result).to be_success
    expect(ssh.remote_exist?(path)).to be true

    ssh.remote_delete(path)
  end

  it 'can upload a file to a particular spot' do
    destination = Settings.batch_analysis.root_data_path_mapping.cluster / 'sub_dir' / 'hello.txt'

    ssh.remote_delete(destination.dirname, recurse: true)
    expect(ssh.remote_exist?(destination)).to be false
    expect(ssh.remote_exist?(destination.dirname)).to be false

    io = StringIO.new('Hello World')

    result = ssh.upload_file(io, destination:)
    expect(result).to be_success
    expect(ssh.remote_exist?(destination)).to be true

    ssh.remote_delete(destination)
  end

  it 'can chmod a file' do
    destination = Settings.batch_analysis.root_data_path_mapping.cluster / 'hello.sh'

    ssh.remote_delete(destination)
    expect(ssh.remote_exist?(destination)).to be false

    io = StringIO.new('echo "Hello World"')

    result = ssh.upload_file(io, destination:)
    expect(result).to be_success

    result = ssh.remote_chmod(destination, '+x')
    expect(result).to be_success

    status, output, _error = ssh.execute(destination)

    expect(status).to eq 0
    expect(output).to eq "Hello World\n"

    ssh.remote_delete(destination)
  end

  it 'can download a file' do
    path = Pathname('hello.txt')

    ssh.remote_delete(path)
    expect(ssh.remote_exist?(path)).to be false

    io = StringIO.new('Hello Download')

    result = ssh.upload_file(io, destination: path)
    expect(result).to be_success

    result = ssh.download_file(path)
    expect(result).to be_success

    expect(result.value!).to eq 'Hello Download'

    ssh.remote_delete(path)
  end

  # the NET:SSH module is _very_ chatty.
  # We use a log level suppressor to force it's logs to a lower level.
  # This did fail in the past, generating gigabytes of logs per minute on prod,
  # so now we test!
  describe 'log levels' do
    include_context 'with a logger spy'

    def fire!
      # execute something that will purposely fail to test different log levels
      exit_code, = ssh.execute('broken')
      expect(exit_code).not_to eq 0
    end

    it 'outputs everything in trace mode', log_level: :trace do
      fire!

      expect_log_entries_to_include(
        a_hash_including(level: 'trace', name: Net::SSH.name),
        a_hash_including(level: 'debug', name: Net::SSH.name),
        a_hash_including(level: 'debug', name: PBS::SSH.name),
        a_hash_including(level: 'error', name: PBS::SSH.name)
      )

      expect_log_entries_to_not_include(
        # because we have no examples of info
        a_hash_including(level: 'info', name: PBS::SSH.name)
      )
    end

    it 'does not emit lower logs at the debug level', log_level: :debug do
      fire!

      expect_log_entries_to_include(
        a_hash_including(level: 'debug', name: PBS::SSH.name),
        a_hash_including(level: 'error', name: PBS::SSH.name),
        a_hash_including(level: 'debug', name: Net::SSH.name)
      )

      expect_log_entries_to_not_include(
        a_hash_including(level: 'trace', name: Net::SSH.name),
        # because we have no examples of info
        a_hash_including(level: 'info', name: PBS::SSH.name)
      )
    end

    it 'does not emit lower logs at the info level', log_level: :info do
      fire!

      expect_log_entries_to_include(
        a_hash_including(level: 'error', name: PBS::SSH.name)
      )

      expect_log_entries_to_not_include(
        a_hash_including(level: 'trace', name: Net::SSH.name),
        a_hash_including(level: 'debug', name: Net::SSH.name),
        a_hash_including(level: 'debug', name: PBS::SSH.name),
        # because we have no examples of info
        a_hash_including(level: 'info', name: PBS::SSH.name)
      )
    end
  end
end
