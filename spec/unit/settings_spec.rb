# frozen_string_literal: true

describe 'Settings' do
  subject {
    Settings
  }

  it { is_expected.to be_a(Config::Options) }
  it { is_expected.to be_a_kind_of(BawWeb::Settings) }

  it 'includes BawWeb::Settings' do
    expect(subject.class.ancestors).to start_with(BawWeb::Settings, Config::Options)
  end

  it 'includes special methods from BawWeb::Settings' do
    expect(subject.methods).to include(
      :supported_media_types,
      :media_category,
      :process_media_locally?,
      :process_media_resque?,
      :min_duration_larger_overlap?
    )
  end

  it 'supports media types' do
    expect(Settings.supported_media_types[:text][0].to_str).to eq('application/json')
  end

  its(:sources) { is_expected.to eq(BawApp.config_files.map(&:to_s)) }

  describe 'versioning' do
    after(:all) do
      Settings.instance_variable_set(:@version_info, nil)
    end

    context 'reads the version from the version file if the ENV var is empty' do
      example 'short version' do
        allow(File).to receive(:read).with(Rails.root / 'VERSION').and_return("1.2.3\n")
        Settings.instance_variable_set(:@version_info, nil)
        expect(Settings.version_info).to eq({
          major: '1',
          minor: '2',
          patch: '3',
          pre: '',
          build: ''
        })
        expect(Settings.version_string).to eq('1.2.3')
      end

      example 'git describe version' do
        allow(File).to receive(:read).with(Rails.root / 'VERSION').and_return("1.2.3-69-gabcdef0\n")
        Settings.instance_variable_set(:@version_info, nil)
        expect(Settings.version_info).to eq({
          major: '1',
          minor: '2',
          patch: '3',
          pre: '69',
          build: 'abcdef0'
        })
        expect(Settings.version_string).to eq('1.2.3-69+abcdef0')
      end
    end
  end

  context 'reads the version from the version ENV var when set' do
    example 'short version' do
      allow(ENV).to receive(:fetch).with('BAW_SERVER_VERSION', nil).and_return("99.88.77\n")
      Settings.instance_variable_set(:@version_info, nil)
      expect(Settings.version_info).to eq({
        major: '99',
        minor: '88',
        patch: '77',
        pre: '',
        build: ''
      })
      expect(Settings.version_string).to eq('99.88.77')
    end

    example 'git describe version' do
      allow(ENV).to receive(:fetch).with('BAW_SERVER_VERSION', nil).and_return("99.88.77-66-g0123459\n")
      Settings.instance_variable_set(:@version_info, nil)
      expect(Settings.version_info).to eq({
        major: '99',
        minor: '88',
        patch: '77',
        pre: '66',
        build: '0123459'
      })
      expect(Settings.version_string).to eq('99.88.77-66+0123459')
    end
  end

  describe 'the upload service settings' do
    example 'validation is done for the upload_service key' do
      config = ::Config::Options.new
      without_upload = Settings.to_hash.except(:upload_service)
      config.add_source!(without_upload)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /upload_service: is missing/)
    end

    [:admin_host, :public_host, :port, :username, :password, :sftp_port].each do |key|
      example "validation is done for sub-key #{key} for upload_service" do
        config = ::Config::Options.new
        copy = Settings.to_hash
        copy[:upload_service].delete(key)
        config.add_source!(copy)

        expect {
          config.reload!
        }.to raise_error(Config::Validation::Error, /#{key}: is missing/)
      end
    end
  end

  describe 'the batch_analysis settings' do
    example 'validation is done for the batch_analysis key' do
      config = ::Config::Options.new
      without_batch_analysis = Settings.to_hash.except(:batch_analysis)
      config.add_source!(without_batch_analysis)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /batch_analysis: is missing/)
    end

    [:host, :port, :username, :password, :key_file].each do |key|
      example "validation is done for sub-key #{key} for batch_analysis" do
        config = ::Config::Options.new
        copy = Settings.to_hash
        copy[:batch_analysis][:connection].delete(key)
        config.add_source!(copy)

        expect {
          config.reload!
        }.to raise_error(Config::Validation::Error, /#{key}: is missing/)
      end
    end

    it 'has a settings helper' do
      ba = Settings.batch_analysis
      expect(ba).to be_an_instance_of(BawApp::BatchAnalysisSettings)

      connection = ba.connection
      expect(connection).to be_an_instance_of(BawApp::BatchAnalysisSettings::ConnectionSettings)
      expect(connection.host).to eq 'analysis_test'
    end
  end

  describe 'new active_* queues' do
    example 'validation is done for active_storage queues' do
      config = ::Config::Options.new
      copy = Settings.to_hash
      copy[:actions].delete(:active_storage)
      config.add_source!(copy)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /active_storage: is missing/)
    end

    example 'validation is done for active_job default queues' do
      config = ::Config::Options.new
      copy = Settings.to_hash
      copy[:actions].delete(:active_job_default)
      config.add_source!(copy)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /active_job_default: is missing/)
    end

    example 'validation is done for active_storage queue name' do
      config = ::Config::Options.new
      copy = Settings.to_hash
      copy[:actions][:active_storage][:queue] = ''
      config.add_source!(copy)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /active_storage.queue: must be filled/)
    end

    example 'validation is done for active_job_default queue name' do
      config = ::Config::Options.new
      copy = Settings.to_hash
      copy[:actions][:active_job_default][:queue] = ''
      config.add_source!(copy)

      expect {
        config.reload!
      }.to raise_error(Config::Validation::Error, /active_job_default.queue: must be filled/)
    end
  end

  example 'it reads IP in allow_list as an IPAddr class' do
    expect(Settings.internal_allow_ips).to all(
      be_an_instance_of(IPAddr)
    )
  end
end
