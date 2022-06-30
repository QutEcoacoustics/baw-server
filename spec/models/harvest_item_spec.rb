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
#  index_harvest_items_on_path    (path)
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (harvest_id => harvests.id)
#  fk_rails_...  (uploader_id => users.id)
#
RSpec.describe HarvestItem, type: :model do
  subject { build(:harvest_item) }

  it 'has a valid factory' do
    expect(create(:harvest_item)).to be_valid
  end

  it { is_expected.to belong_to(:harvest).optional(true) }

  it { is_expected.to belong_to(:audio_recording).optional(true) }
  it { is_expected.to belong_to(:uploader).with_foreign_key(:uploader_id) }

  it { is_expected.to enumerize(:status).in(HarvestItem::STATUSES) }

  it 'encodes the info jsonb' do
    expect(HarvestItem.columns_hash['info'].type).to eq(:jsonb)
  end

  it 'deserializes the info column as an Info object' do
    item = build(:harvest_item)
    item.info = ::BawWorkers::Jobs::Harvest::Info.new(error: 'hello')
    item.save!

    item = HarvestItem.find(item.id)

    expect(item.info).to be_an_instance_of(::BawWorkers::Jobs::Harvest::Info)
    expect(item.info.error).to eq 'hello'
    expect(item.info[:error]).to eq 'hello'
  end

  it 'can find other records that overlap with it' do
    # 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
    # aaaaa
    #       bbbbb-
    #    ccccc
    # dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
    #             eeeee
    a = create_with_durations('a.mp3', 1, Time.new(2019, 1, 1, 0, 0, 0), 7200)
    b = create_with_durations('b.ogg', 1, Time.new(2019, 1, 1, 2, 0, 0), 7205)
    c = create_with_durations('c.wav', 1, Time.new(2019, 1, 1, 1, 0, 0), 7200)
    d = create_with_durations('d.mp3', 2, Time.new(2019, 1, 1, 0, 0, 0), 86_400)
    e = create_with_durations('e.ogg', 1, Time.new(2019, 1, 1, 4, 0, 0), 7200)

    expect(a.overlaps_with).to match_array([c])
    expect(b.overlaps_with).to match_array([c, e])
    expect(c.overlaps_with).to match_array([a, b])

    expect(d.overlaps_with).to match_array([])
    expect(e.overlaps_with).to match_array([b])
  end

  def create_with_durations(path, site_id, recorded_date, duration_seconds)
    info = ::BawWorkers::Jobs::Harvest::Info.new(
      file_info: {
        duration_seconds:,
        recorded_date:,
        site_id:
      }
    )
    create(:harvest_item, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:)
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
        results = HarvestItem.project_directory_listing(HarvestItem.all, '').as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, 'a', 5, 2, 1),
          assert(nil, 'z', 1, 1, 0),
          assert(@hi1.id, @hi1.path, 1, 0, 1),
          assert(@hi2.id, @hi2.path, 1, 0, 1),
          assert(@hi3.id, @hi3.path, 1, 1, 0)
        ))
      end

      it 'can query a sub directory "a"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, 'a').as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, 'a/b', 5, 2, 1)
        ))
      end

      it 'can query a sub directory "a/b"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, 'a/b').as_json

        expect(results).to match(a_collection_containing_exactly(
          assert(nil, 'a/b/c', 2, 0, 1),
          assert(nil, 'a/b/d', 1, 0, 0),
          assert(@hi7.id, @hi7.path, 1, 1, 0),
          assert(@hi8.id, @hi8.path, 1, 1, 0)
        ))
      end

      it 'can query a deep directory "a/b/c"' do
        results = HarvestItem.project_directory_listing(HarvestItem.all, 'a/b/c').as_json

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

    def create_with_validations(fixable: 0, not_fixable: 0, sub_directories: nil)
      validations = []
      fixable.times do
        validations << ::BawWorkers::Jobs::Harvest::ValidationResult.new(
          status: :fixable,
          name: :wascally_wabbit,
          message: nil
        )
      end
      not_fixable.times do
        validations << ::BawWorkers::Jobs::Harvest::ValidationResult.new(
          status: :not_fixable,
          name: :kiww_the_wabbit,
          message: nil
        )
      end

      info = ::BawWorkers::Jobs::Harvest::Info.new(
        validations:
      )

      path = generate_recording_name(Time.now)
      path = File.join(sub_directories, path) if sub_directories.present?

      create(:harvest_item, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:, harvest:)
    end
  end
end
