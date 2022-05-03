# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
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
end
