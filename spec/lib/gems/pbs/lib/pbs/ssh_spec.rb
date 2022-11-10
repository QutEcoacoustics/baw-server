# frozen_string_literal: true

describe PBS::SSH do
  # make all instance methods public for testing1
  PBS::SSH.class_eval do
    # rubocop:disable Style/AccessModifierDeclarations
    public(*private_instance_methods(false))
    # rubocop:enable Style/AccessModifierDeclarations
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
end
