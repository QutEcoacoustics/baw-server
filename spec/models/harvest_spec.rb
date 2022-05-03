# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id              :bigint           not null, primary key
#  mappings        :jsonb
#  status          :string
#  streaming       :boolean
#  upload_password :string
#  upload_user     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :integer
#  project_id      :integer          not null
#  updater_id      :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
RSpec.describe Harvest, type: :model do
  prepare_users
  prepare_project

  subject { build(:harvest) }

  it 'has a valid factory' do
    expect(create(:harvest)).to be_valid
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional(true) }

  it { is_expected.to validate_presence_of(:project) }

  it 'encodes the mappings column as jsonb' do
    expect(Harvest.columns_hash['mappings'].type).to eq(:jsonb)
  end

  it 'can generate a upload url' do
    expect(subject.upload_url).to eq "sftp://#{Settings.upload_service.host}:#{Settings.upload_service.sftp_port}"
  end

  it 'will fail to create a harvest if uploading is not enabled for the project' do
    project.allow_audio_upload = false
    project.save!

    harvest = Harvest.new(project:)

    expect(harvest).not_to be_valid
    expect(harvest).to have(1).error_on(:project)
    expect(harvest.errors_on(:project)).to include(
      'A harvest cannot be created unless its parent project has enabled audio upload'
    )
  end

  it 'has a upload directory name' do
    expect(subject.upload_directory_name).to eq "harvest_#{subject.id}"
  end

  it 'has a upload directory path' do
    root =  Pathname('/data/test/harvester_to_do/')
    expect(subject.upload_directory).to eq(
      root / subject.upload_directory_name
    )
  end

  context 'when translating a path to a harvest' do
    before do
      subject.save!
    end

    it 'can find a harvest by a path' do
      path = "/data/test/harvester_to_do/harvest_#{subject.id}/test-audio-mono.ogg"

      actual = Harvest.fetch_harvest_from_absolute_path(path)
      expect(actual).to eq subject
    end

    it 'will return nil with a bad argument (bad path)' do
      path = "/data/test/harvester_to_do/#{subject.id}/test-audio-mono.ogg"

      actual = Harvest.fetch_harvest_from_absolute_path(path)
      expect(actual).to be_nil
    end

    it 'will return nil with a bad argument (nil)' do
      path = nil

      actual = Harvest.fetch_harvest_from_absolute_path(path)
      expect(actual).to be_nil
    end

    it 'will return nil with a bad argument (missing harvest id)' do
      path = '/data/test/harvester_to_do/9999/test-audio-mono.ogg'

      actual = Harvest.fetch_harvest_from_absolute_path(path)
      expect(actual).to be_nil
    end
  end

  context 'when checking if a path is in the harvest directory' do
    it 'works for files' do
      path = "harvest_#{subject.id}/test-audio-mono.ogg"

      expect(subject.path_within_harvest_dir(path)).to be true
    end

    it 'works for directories' do
      path = "harvest_#{subject.id}/a"

      expect(subject.path_within_harvest_dir(path)).to be true
    end

    it 'throws if we try a absolute path' do
      path = "/data/test/harvester_to_do/harvest_#{subject.id}/a"

      expect {
        subject.path_within_harvest_dir(path)
      }.to raise_error(ArgumentError, 'path cannot be a root path')
    end

    it 'returns false for incorrect paths' do
      path = 'harvest_123/test-audio-mono.ogg'

      expect(subject.path_within_harvest_dir(path)).to be false
    end

    it 'returns false for incorrect paths (root file)' do
      path = 'test-audio-mono.ogg'

      expect(subject.path_within_harvest_dir(path)).to be false
    end

    it 'returns false for incorrect paths (empty)' do
      path = ''

      expect(subject.path_within_harvest_dir(path)).to be false
    end
  end

  context 'when mapping a path to a mapping of metadata' do
    before do
      subject.save!
    end

    let(:file_a) {
      "harvest_#{subject.id}/a/123.wav"
    }
    let(:file_b) {
      "harvest_#{subject.id}/456.mp3"
    }
    let(:file_c) {
      "harvest_#{subject.id}/a/b/c/789.ogg"
    }

    let(:files) {
      [file_a, file_b, file_c]
    }

    let(:args) {
      {
        site_id: 1,
        utc_offset: '+10:00'
      }
    }

    it 'will map everything with a root recursive mapping' do
      mapping = BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, **args)

      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([mapping])

      expect(subject.find_mapping_for_path(file_a)).to eq mapping
      expect(subject.find_mapping_for_path(file_b)).to eq mapping
      expect(subject.find_mapping_for_path(file_c)).to eq mapping
    end

    it 'will only map the current directory without recurse' do
      mapping = BawWorkers::Jobs::Harvest::Mapping.new(
        path: '/',
        recursive: false,
        **args
      )

      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([mapping])

      expect(subject.find_mapping_for_path(file_a)).to be_nil
      expect(subject.find_mapping_for_path(file_b)).to eq mapping
      expect(subject.find_mapping_for_path(file_c)).to be_nil
    end

    it 'will not map without any mappings' do
      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([])

      expect(subject.find_mapping_for_path(file_a)).to be_nil
      expect(subject.find_mapping_for_path(file_b)).to be_nil
      expect(subject.find_mapping_for_path(file_c)).to be_nil
    end

    it 'will not map without any matching mappings' do
      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([
        BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/z', recursive: true, **args),
        BawWorkers::Jobs::Harvest::Mapping.new(path: '/donkey', recursive: true, **args)
      ])

      expect(subject.find_mapping_for_path(file_a)).to be_nil
      expect(subject.find_mapping_for_path(file_b)).to be_nil
      expect(subject.find_mapping_for_path(file_c)).to be_nil
    end

    it 'will map with specific mappings' do
      mapping1 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a', recursive: false, **args)
      mapping2 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: false, **args)
      mapping3 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b/c', recursive: false, **args)
      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([
        mapping1, mapping2, mapping3
      ])

      expect(subject.find_mapping_for_path(file_a)).to eq mapping1
      expect(subject.find_mapping_for_path(file_b)).to eq mapping2
      expect(subject.find_mapping_for_path(file_c)).to eq mapping3
    end

    it 'will map with correctly with overlapping mappings - more specific takes priority' do
      mapping1 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a', recursive: false, **args)
      mapping2 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, **args)
      mapping3 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b', recursive: true, **args)
      mapping4 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b/c', recursive: false, **args)
      subject.mappings = BawWorkers::Jobs::Harvest::Mappings.new([
        mapping1, mapping2, mapping3, mapping4
      ])

      expect(subject.find_mapping_for_path(file_a)).to eq mapping1
      expect(subject.find_mapping_for_path(file_b)).to eq mapping2
      expect(subject.find_mapping_for_path(file_c)).to eq mapping4
    end
  end
end
