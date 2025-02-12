# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  deleted            :boolean          default(FALSE)
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  harvest_id         :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_harvest_id  (harvest_id)
#  index_harvest_items_on_info        (info) USING gin
#  index_harvest_items_on_path        (path) UNIQUE
#  index_harvest_items_on_status      (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  fk_rails_...  (harvest_id => harvests.id) ON DELETE => cascade
#  fk_rails_...  (uploader_id => users.id)
#
RSpec.describe HarvestItem do
  subject { build(:harvest_item) }

  it 'has a valid factory' do
    expect(create(:harvest_item)).to be_valid
  end

  it { is_expected.to belong_to(:harvest).optional(true) }

  it { is_expected.to belong_to(:audio_recording).optional(true) }
  it { is_expected.to belong_to(:uploader) }

  it { is_expected.to enumerize(:status).in(HarvestItem::STATUSES) }

  it 'encodes the info jsonb' do
    expect(HarvestItem.columns_hash['info'].type).to eq(:jsonb)
  end

  it 'deserializes the info column as an Info object' do
    item = build(:harvest_item)
    item.info = BawWorkers::Jobs::Harvest::Info.new(error: 'hello')
    item.save!

    item = HarvestItem.find(item.id)

    expect(item.info).to be_an_instance_of(BawWorkers::Jobs::Harvest::Info)
    expect(item.info.error).to eq 'hello'
    expect(item.info[:error]).to eq 'hello'
  end

  context 'with overlaps' do
    prepare_users
    prepare_project
    prepare_harvest

    it 'can find other records that overlap with it' do
      # 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
      # aaaaa
      #       bbbbb-
      #    ccccc
      # dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
      #             eeeee
      a = create_with_durations('a.mp3', 1, Time.zone.local(2019, 1, 1, 0, 0, 0), 7200, harvest)
      b = create_with_durations('b.ogg', 1, Time.zone.local(2019, 1, 1, 2, 0, 0), 7205, harvest)
      c = create_with_durations('c.wav', 1, Time.zone.local(2019, 1, 1, 1, 0, 0), 7200, harvest)
      # different site!
      d = create_with_durations('d.mp3', 2, Time.zone.local(2019, 1, 1, 0, 0, 0), 86_400, harvest)
      e = create_with_durations('e.ogg', 1, Time.zone.local(2019, 1, 1, 4, 0, 0), 7200, harvest)

      expect(a.overlaps_with).to contain_exactly(c)
      expect(b.overlaps_with).to contain_exactly(c, e)
      expect(c.overlaps_with).to contain_exactly(a, b)

      expect(d.overlaps_with).to be_empty
      expect(e.overlaps_with).to contain_exactly(b)
    end

    it 'does not find other records that overlap with it from a different harvest' do
      other_harvest = Harvest.new(project:, creator: owner_user)
      other_harvest.save!

      #   | 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
      # 1 | aaaaa
      # 1 |       bbbbb-
      # 2 |    ccccc
      # 2 | dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
      # 1           eeeee
      a = create_with_durations('a.mp3', 1, Time.zone.local(2019, 1, 1, 0, 0, 0), 7200, harvest)
      b = create_with_durations('b.ogg', 1, Time.zone.local(2019, 1, 1, 2, 0, 0), 7205, harvest)
      c = create_with_durations('c.wav', 1, Time.zone.local(2019, 1, 1, 1, 0, 0), 7200, other_harvest)
      # different site!
      d = create_with_durations('d.mp3', 2, Time.zone.local(2019, 1, 1, 0, 0, 0), 86_400, other_harvest)
      e = create_with_durations('e.ogg', 1, Time.zone.local(2019, 1, 1, 4, 0, 0), 7200, harvest)

      expect(a.overlaps_with).to be_empty
      expect(b.overlaps_with).to contain_exactly(e)
      expect(c.overlaps_with).to be_empty

      expect(d.overlaps_with).to be_empty
      expect(e.overlaps_with).to contain_exactly(b)
    end

    def create_with_durations(path, site_id, recorded_date, duration_seconds, harvest)
      info = BawWorkers::Jobs::Harvest::Info.new(
        file_info: {
          duration_seconds:,
          recorded_date:,
          site_id:
        }
      )
      create(:harvest_item, harvest:, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:)
    end
  end

  context 'with duplicate hashes' do
    prepare_users
    prepare_project
    prepare_harvest

    it 'can find other records that have a duplicate hash' do
      a = create_with_hashes('a.mp3', 1, 'imaahash', harvest)
      b = create_with_hashes('b.ogg', 1, 'imumnotuhhahash', harvest)
      c = create_with_hashes('c.wav', 1, 'imaahash', harvest)
      # different site!
      d = create_with_hashes('d.mp3', 2, 'imaahash', harvest)

      expect(a.duplicate_hash_of).to contain_exactly(c, d)
      expect(b.duplicate_hash_of).to be_empty
      expect(c.duplicate_hash_of).to contain_exactly(a, d)

      expect(d.duplicate_hash_of).to contain_exactly(a, c)
    end

    it 'does not find other records that have a duplicate hash from a different harvest' do
      other_harvest = Harvest.new(project:, creator: owner_user)
      other_harvest.save!

      a = create_with_hashes('a.mp3', 1, 'imaahash', harvest)
      # different site!
      b = create_with_hashes('b.ogg', 2, 'imumnotuhhahash', harvest)
      # different harvests!
      c = create_with_hashes('c.wav', 1, 'imaahash', other_harvest)
      # different site!
      d = create_with_hashes('d.mp3', 2, 'imaahash', other_harvest)

      expect(a.duplicate_hash_of).to be_empty
      expect(b.duplicate_hash_of).to be_empty
      expect(c.duplicate_hash_of).to contain_exactly(d)

      expect(d.duplicate_hash_of).to contain_exactly(c)
    end

    def create_with_hashes(path, site_id, file_hash, harvest)
      info = BawWorkers::Jobs::Harvest::Info.new(
        file_info: {
          file_hash:,
          site_id:
        }
      )
      create(:harvest_item, harvest:, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:)
    end
  end

  context 'with other models' do
    prepare_users
    prepare_project
    prepare_region
    prepare_site
    prepare_harvest

    it 'can query based on validation state' do
      # valid
      create_with_validations
      # invalid: not fixable
      create_with_validations(fixable: 3, not_fixable: 1)
      # invalid: not fixable
      create_with_validations(fixable: 0, not_fixable: 1)
      # invalid: fixable
      create_with_validations(fixable: 1, not_fixable: 0)

      aggregate_failures do
        expect(HarvestItem.sum(HarvestItem.valid_arel)).to eq 1
        expect(HarvestItem.sum(HarvestItem.invalid_fixable_arel)).to eq 1
        expect(HarvestItem.sum(HarvestItem.invalid_not_fixable_arel)).to eq 2
        expect(HarvestItem.count).to eq 4
      end
    end

    context 'when querying based on path to return a pseudo directory listing' do
      before do
        @hi1 = create_with_validations(fixable: 3, not_fixable: 1)
        @hi2 = create_with_validations(fixable: 0, not_fixable: 1)
        @hi3 = create_with_validations(fixable: 1, not_fixable: 0)
        @hi4 = create_with_validations(fixable: 0, not_fixable: 1, sub_directories: 'a/b/c')
        @hi5 = create_with_validations(fixable: 0, not_fixable: 0, sub_directories: 'a/b/c')
        @hi6 = create_with_validations(fixable: 0, not_fixable: 0, sub_directories: 'a/b/d')
        @hi7 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'a/b')
        @hi8 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'a/b')
        @hi9 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'z/b')
      end

      def assert(id, path, total, fixable, not_fixable)
        a_hash_including(
          'id' => id,
          'path' => path,
          'harvest_id' => harvest.id,
          'items_invalid_fixable' => fixable,
          'items_invalid_not_fixable' => not_fixable,
          'items_total' => total
        )
      end

      it 'can query the root path' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, harvest.upload_directory_name).as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, "#{harvest.upload_directory_name}/a", 5, 2, 1),
          assert(nil, "#{harvest.upload_directory_name}/z", 1, 1, 0),
          assert(@hi1.id, @hi1.path, 1, 0, 1),
          assert(@hi2.id, @hi2.path, 1, 0, 1),
          assert(@hi3.id, @hi3.path, 1, 1, 0)
        ))
      end

      it 'can query a sub directory "a"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, "#{harvest.upload_directory_name}/a").as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, "#{harvest.upload_directory_name}/a/b", 5, 2, 1)
        ))
      end

      it 'can query a sub directory "a/b"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, "#{harvest.upload_directory_name}/a/b").as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, "#{harvest.upload_directory_name}/a/b/c", 2, 0, 1),
          assert(nil, "#{harvest.upload_directory_name}/a/b/d", 1, 0, 0),
          assert(@hi7.id, @hi7.path, 1, 1, 0),
          assert(@hi8.id, @hi8.path, 1, 1, 0)
        ))
      end

      it 'can query a deep directory "a/b/c"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all,
          "#{harvest.upload_directory_name}/a/b/c").as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(@hi4.id, @hi4.path, 1, 0, 1),
          assert(@hi5.id, @hi5.path, 1, 0, 0)
        ))
      end

      it 'we are not vulnerable to sql injection' do
        results = HarvestItem
          .project_directory_listing(HarvestItem.all, "a' or 1=1 --")
          .as_json

        expect(results).to eq []
      end
    end
  end
end
