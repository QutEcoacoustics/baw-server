# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id                      :bigint           not null, primary key
#  last_mappings_change_at :datetime
#  last_metadata_review_at :datetime
#  last_upload_at          :datetime
#  mappings                :jsonb
#  name                    :string
#  status                  :string
#  streaming               :boolean
#  upload_password         :string
#  upload_user             :string
#  upload_user_expiry_at   :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  creator_id              :integer
#  project_id              :integer          not null
#  updater_id              :integer
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
  prepare_region
  prepare_site

  subject { build(:harvest) }

  let(:harvest) { subject }

  it 'has a valid factory' do
    expect(create(:harvest)).to be_valid
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional(true) }

  it { is_expected.to validate_presence_of(:project) }

  context 'when changing the name' do
    before do
      Timecop.freeze
    end

    after do
      Timecop.return
    end

    it 'has a default value for the name column' do
      n = Time.now
      subject.save!

      expect(subject.name).to eq "#{n.strftime('%B')} #{n.day.ordinalize} Upload"
    end

    it 'sets a default value for the name column on update if name is null' do
      # create makes a default name
      subject.save!

      # update with a blank name
      subject.name = nil
      subject.save!

      n = subject.created_at
      expect(subject.name).to eq "#{n.strftime('%B')} #{n.day.ordinalize} Upload"
    end

    it 'can be created with a custom name' do
      subject.name = 'hello'
      subject.save!

      expect(subject.name).to eq 'hello'
    end

    it 'can be updated with a custom name' do
      subject.save!
      subject.name = 'world'
      subject.save!

      expect(subject.name).to eq 'world'
    end
  end

  it 'encodes the mappings column as jsonb' do
    expect(Harvest.columns_hash['mappings'].type).to eq(:jsonb)
  end

  it 'saves a date stamp whenever mappings are updated' do
    expect(harvest.last_mappings_change_at).to be_nil
    harvest.save!
    expect(harvest.last_mappings_change_at).to be_nil

    harvest.mappings = [
      BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, site_id: site.id, utc_offset: '+10:00')
    ]
    harvest.save!
    now = Time.now
    expect(harvest.last_mappings_change_at).to be_within(0.01.second).of(now)

    sleep 1

    # date stamp not modified on reload
    harvest.reload
    expect(harvest.last_mappings_change_at).to be_within(0.05.second).of(now)

    sleep 1

    # not updated if equivalent
    harvest.mappings = [
      BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, site_id: site.id, utc_offset: '+10:00')
    ]
    harvest.save!
    harvest.reload
    expect(harvest.last_mappings_change_at).to be_within(0.05.second).of(now)

    sleep 1

    # is updated if different
    harvest.mappings = [
      BawWorkers::Jobs::Harvest::Mapping.new(path: '/abc', recursive: true, site_id: site.id, utc_offset: '+10:00')
    ]
    now = Time.now
    harvest.save!
    harvest.reload
    expect(harvest.last_mappings_change_at).to be_within(0.05.second).of(now)
  end

  it 'can generate a upload url' do
    expect(harvest.upload_url).to eq "sftp://#{Settings.upload_service.public_host}:#{Settings.upload_service.sftp_port}"
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
    expect(harvest.upload_directory_name).to eq "harvest_#{harvest.id}"
  end

  it 'has a upload directory path' do
    root =  Pathname('/data/test/harvester_to_do/')
    expect(harvest.upload_directory).to eq(
      root / harvest.upload_directory_name
    )
  end

  context 'when translating a path to a harvest' do
    before do
      harvest.save!
    end

    it 'can find a harvest by a path' do
      path = "/data/test/harvester_to_do/harvest_#{harvest.id}/test-audio-mono.ogg"

      actual = Harvest.fetch_harvest_from_absolute_path(path)
      expect(actual).to eq subject
    end

    it 'will return nil with a bad argument (bad path)' do
      path = "/data/test/harvester_to_do/#{harvest.id}/test-audio-mono.ogg"

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
      path = "harvest_#{harvest.id}/test-audio-mono.ogg"

      expect(harvest.path_within_harvest_dir(path)).to be true
    end

    it 'works for directories' do
      path = "harvest_#{harvest.id}/a"

      expect(harvest.path_within_harvest_dir(path)).to be true
    end

    it 'accepts an absolute path and treats it as a path contained withing the harvest dir' do
      path = "/data/test/harvester_to_do/harvest_#{harvest.id}/a"

      expect(harvest.path_within_harvest_dir(path)).to be false
    end

    it 'accepts path with a leading slash and treats it as a path contained withing the harvest dir' do
      path = "/harvest_#{harvest.id}/test-audio-mono.ogg"

      expect(harvest.path_within_harvest_dir(path)).to be true
    end

    it 'returns false for incorrect paths' do
      path = 'harvest_123/test-audio-mono.ogg'

      expect(harvest.path_within_harvest_dir(path)).to be false
    end

    it 'returns false for incorrect paths (root file)' do
      path = 'test-audio-mono.ogg'

      expect(harvest.path_within_harvest_dir(path)).to be false
    end

    it 'returns false for incorrect paths (empty)' do
      path = ''

      expect(harvest.path_within_harvest_dir(path)).to be false
    end
  end

  context 'when mapping a path to a mapping of metadata' do
    before do
      harvest.save!
    end

    let(:file_a) { "harvest_#{harvest.id}/a/123.wav" }

    let(:file_b) { "harvest_#{harvest.id}/456.mp3" }

    let(:file_c) { "harvest_#{harvest.id}/a/b/c/789.ogg" }

    let(:file_d) { "harvest_#{harvest.id}/aaaaaaaaa/1011.wav" }

    let(:args) {
      {
        site_id: 1,
        utc_offset: '+10:00'
      }
    }

    it 'will map everything with a root recursive mapping' do
      mapping = BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, **args)

      harvest.mappings = [mapping]

      expect(harvest.find_mapping_for_path(file_a)).to eq mapping
      expect(harvest.find_mapping_for_path(file_b)).to eq mapping
      expect(harvest.find_mapping_for_path(file_c)).to eq mapping
      expect(harvest.find_mapping_for_path(file_d)).to eq mapping
    end

    it 'will only map the current directory without recurse' do
      mapping = BawWorkers::Jobs::Harvest::Mapping.new(
        path: '/',
        recursive: false,
        **args
      )

      harvest.mappings = [mapping]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to eq mapping
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will not map without any mappings' do
      harvest.mappings = []

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will not map without any matching mappings' do
      harvest.mappings = [
        BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/z', recursive: true, **args),
        BawWorkers::Jobs::Harvest::Mapping.new(path: '/donkey', recursive: true, **args)
      ]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will map with specific mappings' do
      mapping1 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a', recursive: false, **args)
      mapping2 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: false, **args)
      mapping3 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b/c', recursive: false, **args)
      harvest.mappings = [
        mapping1, mapping2, mapping3
      ]

      expect(harvest.find_mapping_for_path(file_a)).to eq mapping1
      expect(harvest.find_mapping_for_path(file_b)).to eq mapping2
      expect(harvest.find_mapping_for_path(file_c)).to eq mapping3
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will map with correctly with overlapping mappings - more specific takes priority' do
      mapping1 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a', recursive: false, **args)
      mapping2 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/', recursive: true, **args)
      mapping3 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b', recursive: true, **args)
      mapping4 =  BawWorkers::Jobs::Harvest::Mapping.new(path: '/a/b/c', recursive: false, **args)
      harvest.mappings = [
        mapping1, mapping2, mapping3, mapping4
      ]

      expect(harvest.find_mapping_for_path(file_a)).to eq mapping1
      expect(harvest.find_mapping_for_path(file_b)).to eq mapping2
      expect(harvest.find_mapping_for_path(file_c)).to eq mapping4
      expect(harvest.find_mapping_for_path(file_d)).to eq mapping2
    end

    it 'will match whole segments of a path' do
      mapping1 = BawWorkers::Jobs::Harvest::Mapping.new(path: '/aaaaaaaaaaaaaaa', recursive: false, **args)

      harvest.mappings = [
        mapping1
      ]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will match whole segments of a path (recursive)' do
      mapping1 = BawWorkers::Jobs::Harvest::Mapping.new(path: '/aaaaaaaaaaaaaaa', recursive: true, **args)

      harvest.mappings = [
        mapping1
      ]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will match whole segments of a path (path shorter than file name)' do
      mapping1 = BawWorkers::Jobs::Harvest::Mapping.new(path: '/aaa', recursive: false, **args)

      harvest.mappings = [
        mapping1
      ]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end

    it 'will match whole segments of a path (path shorter than file name)(recursive)' do
      mapping1 = BawWorkers::Jobs::Harvest::Mapping.new(path: '/aaa', recursive: true, **args)

      harvest.mappings = [
        mapping1
      ]

      expect(harvest.find_mapping_for_path(file_a)).to be_nil
      expect(harvest.find_mapping_for_path(file_b)).to be_nil
      expect(harvest.find_mapping_for_path(file_c)).to be_nil
      expect(harvest.find_mapping_for_path(file_d)).to be_nil
    end
  end

  context 'when transitioning', :clean_by_truncation do
    let(:upload_communicator) {
      BawWorkers::Config.upload_communicator
    }

    pause_all_jobs
    ignore_pending_jobs

    before do
      BawWorkers::Config.upload_communicator.delete_all_users
    end

    it 'will renable the sftpgo user if it already exists' do
      harvest.save!
      harvest.open_upload!

      name = harvest.upload_user
      user = upload_communicator.get_user(name)
      expect(user.username).to eq(name)
      expect(user.status).to eq SftpgoClient::User::USER_STATUS_ENABLED

      harvest.scan!

      user = upload_communicator.get_user(name)
      expect(user.username).to eq(name)
      expect(user.status).to eq SftpgoClient::User::USER_STATUS_DISABLED

      harvest.extract!
      harvest.metadata_review!
      expect(subject).to be_metadata_review

      harvest.open_upload!

      user = upload_communicator.get_user(name)
      expect(user.username).to eq(name)
      expect(user.status).to eq SftpgoClient::User::USER_STATUS_ENABLED
    end

    it 'when entering :uploading state it sets the last upload date' do
      expect(harvest.last_upload_at).to be_nil
      harvest.open_upload!
      expect(harvest.last_upload_at).to be_within(0.01.seconds).of(Time.now)

      harvest.scan!
      harvest.extract!
      harvest.metadata_review!

      expect(subject).to be_metadata_review
      sleep 1

      harvest.open_upload!
      expect(harvest.last_upload_at).to be_within(0.1.seconds).of(Time.now)
    end

    it 'when opening uploads, stores user information' do
      harvest.save!
      harvest.open_upload!

      harvest.reload

      expect(harvest.upload_user).to eq "#{harvest.creator.safe_user_name}_#{harvest.id}"
      expect(harvest.upload_password).to be_present
    end

    it 'when re-entering metadata extraction it re-enqueues all harvest items' do
      harvest.save!
      harvest.open_upload!
      harvest.scan!
      perform_jobs(count: 1)
      harvest.extract!
      harvest.metadata_review!

      expect_enqueued_jobs(0, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      3.times do |i|
        item = HarvestItem.new(
          path: "banana#{i}",
          status: HarvestItem::STATUS_METADATA_GATHERED,
          uploader_id: harvest.creator_id,
          info: {},
          harvest: subject
        )
        item.save!
      end

      harvest.extract!

      expect_enqueued_jobs(1, of_class: ::BawWorkers::Jobs::Harvest::ReenqueueJob)
      perform_jobs(count: 1)
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)

      jobs = expect_enqueued_jobs(3, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      expect(jobs.map { |j| j.dig('args', 0, 'arguments') }).to all(match(
        [an_instance_of(Integer), false]
      ))

      expect(HarvestItem.all).to all(be_new)
    end

    it 'when entering process it re-enqueues all harvest items' do
      harvest.save!
      harvest.open_upload!
      harvest.scan!
      perform_jobs(count: 1)
      harvest.extract!
      harvest.metadata_review!

      expect_enqueued_jobs(0, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      3.times do |i|
        item = HarvestItem.new(
          path: "donkey#{i}",
          status: HarvestItem::STATUS_METADATA_GATHERED,
          uploader_id: harvest.creator_id,
          info: {},
          harvest: subject
        )
        item.save!
      end

      harvest.process!

      expect_enqueued_jobs(1, of_class: ::BawWorkers::Jobs::Harvest::ReenqueueJob)
      perform_jobs(count: 1)
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)

      jobs = expect_enqueued_jobs(3, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      expect(jobs.map { |j| j.dig('args', 0, 'arguments') }).to all(match(
        [an_instance_of(Integer), true]
      ))

      expect(HarvestItem.all).to all(be_new)
    end

    it 'when entering metadata_review it saves a date stamp' do
      harvest.save!
      harvest.open_upload!
      harvest.scan!
      harvest.extract!

      expect(harvest.last_metadata_review_at).to be_nil
      harvest.metadata_review!
      expect(harvest.last_metadata_review_at).to be_within(0.1.seconds).of(Time.now)

      # and it updates it on reentry
      harvest.extract!
      sleep 1
      harvest.metadata_review!
      expect(harvest.last_metadata_review_at).to be_within(0.1.seconds).of(Time.now)
    end
  end
end
