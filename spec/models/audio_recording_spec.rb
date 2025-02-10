# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recordings
#
#  id                  :integer          not null, primary key
#  bit_rate_bps        :integer
#  channels            :integer
#  data_length_bytes   :bigint           not null
#  deleted_at          :datetime
#  duration_seconds    :decimal(10, 4)   not null
#  file_hash           :string(524)      not null
#  media_type          :string           not null
#  notes               :text
#  original_file_name  :string
#  recorded_date       :datetime         not null
#  recorded_utc_offset :string(20)
#  sample_rate_hertz   :integer
#  status              :string           default("new")
#  uuid                :string(36)       not null
#  created_at          :datetime
#  updated_at          :datetime
#  creator_id          :integer          not null
#  deleter_id          :integer
#  site_id             :integer          not null
#  updater_id          :integer
#  uploader_id         :integer          not null
#
# Indexes
#
#  audio_recordings_created_updated_at      (created_at,updated_at)
#  audio_recordings_icase_file_hash_id_idx  (lower((file_hash)::text), id)
#  audio_recordings_icase_file_hash_idx     (lower((file_hash)::text))
#  audio_recordings_icase_uuid_id_idx       (lower((uuid)::text), id)
#  audio_recordings_icase_uuid_idx          (lower((uuid)::text))
#  audio_recordings_uuid_uidx               (uuid) UNIQUE
#  index_audio_recordings_on_creator_id     (creator_id)
#  index_audio_recordings_on_deleter_id     (deleter_id)
#  index_audio_recordings_on_site_id        (site_id)
#  index_audio_recordings_on_updater_id     (updater_id)
#  index_audio_recordings_on_uploader_id    (uploader_id)
#
# Foreign Keys
#
#  audio_recordings_creator_id_fk   (creator_id => users.id)
#  audio_recordings_deleter_id_fk   (deleter_id => users.id)
#  audio_recordings_site_id_fk      (site_id => sites.id) ON DELETE => cascade
#  audio_recordings_updater_id_fk   (updater_id => users.id)
#  audio_recordings_uploader_id_fk  (uploader_id => users.id)
#
describe AudioRecording do
  it 'has a valid factory' do
    ar = create(:audio_recording,
      recorded_date: Time.zone.now.advance(seconds: -20),
      duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar).to be_valid
  end

  it 'has a valid FactoryBot factory' do
    ar = create(:audio_recording,
      recorded_date: Time.zone.now.advance(seconds: -10),
      duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar).to be_valid
  end

  it 'has a valid FactoryBot factory' do
    ar = create(:audio_recording)
    expect(ar).to be_valid
  end

  it 'creating it with a nil :uuid will not generate one on validation' do
    # so because it is auto generated, setting :uuid to nil won't work here
    expect(build(:audio_recording, uuid: nil)).not_to be_valid
  end

  it 'is invalid without a uuid' do
    ar = create(:audio_recording)
    ar.uuid = nil
    expect(ar.save).to be_falsey
    expect(ar).not_to be_valid
  end

  it 'has a uuid when created' do
    ar = build(:audio_recording)
    expect(ar.uuid).not_to be_nil
  end

  it 'has same uuid before and after saved to db' do
    ar = build(:audio_recording)
    uuid_before = ar.uuid
    expect(ar).to be_valid
    expect(ar.uuid).not_to be_nil

    ar.save!
    uuid_after = ar.uuid
    expect(uuid_after).to eq(uuid_before)
  end

  it 'fails validation when uploader is nil' do
    test_item = build(:audio_recording)
    test_item.uploader = nil

    expect(subject).not_to be_valid
    expect(subject.errors[:uploader].size).to eq(1)
    expect(subject.errors[:uploader].to_s).to match(/must exist/)
  end

  it 'has a recent items scope' do
    create_list(:audio_recording, 20)

    events = AudioRecording.most_recent(5).to_a
    expect(events).to have(5).items
    expect(AudioRecording.order(created_at: :desc).limit(5).to_a).to eq(events)
  end

  it 'has a created_within scope' do
    old = create(:audio_recording, created_at: 2.months.ago)

    actual = AudioRecording.created_within(1.month.ago)
    expect(actual.count).to eq(AudioRecording.count - 1)
    expect(actual).not_to include(old)
  end

  it 'has a total bytes helper' do
    n = 0
    create_list(:audio_recording, 10) do |item|
      n += 1
      item.data_length_bytes = n * 1_000_000_000
      item.save!
    end

    total = AudioRecording.total_data_bytes
    expect(total).to an_instance_of(BigDecimal)
    expect(total).to eq(55_000_000_000)
  end

  it 'has a total duration scope' do
    create_list(:audio_recording, 10) do |item|
      # field is limited to < 1M
      item.duration_seconds = 999_999
      item.save!
    end

    total = AudioRecording.total_duration_seconds
    expect(total).to an_instance_of(BigDecimal)
    expect(total).to eq(9_999_990)
  end

  context 'validation' do
    subject { build(:audio_recording) }

    it { is_expected.to belong_to(:creator) }
    it { is_expected.to belong_to(:updater).optional }
    it { is_expected.to belong_to(:deleter).optional }
    it { is_expected.to belong_to(:uploader) }

    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:audio_events) }
    it { is_expected.to have_many(:bookmarks) }
    it { is_expected.to have_many(:tags) }
    it { is_expected.to have_one(:statistics) }

    it { is_expected.to accept_nested_attributes_for(:site) }
    it { is_expected.to serialize(:notes) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(AudioRecording::AVAILABLE_STATUSES) }

    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_length_of(:uuid).is_equal_to(36) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }

    it { is_expected.to validate_presence_of(:recorded_date) }
    it { is_expected.not_to allow_value(7.days.from_now).for(:recorded_date) }
    it { is_expected.not_to allow_value('something').for(:recorded_date) }

    it { is_expected.to validate_presence_of(:duration_seconds) }

    it do
      expect(subject).to validate_numericality_of(:duration_seconds).is_greater_than_or_equal_to(Settings.audio_recording_min_duration_sec)
    end

    it { is_expected.to allow_value(Settings.audio_recording_min_duration_sec).for(:duration_seconds) }
    it { is_expected.not_to allow_value(Settings.audio_recording_min_duration_sec - 0.5).for(:duration_seconds) }

    it { is_expected.to validate_presence_of(:sample_rate_hertz) }
    it { is_expected.to validate_numericality_of(:sample_rate_hertz).is_greater_than(0).only_integer }

    it { is_expected.to validate_presence_of(:channels) }
    it { is_expected.to validate_numericality_of(:channels).is_greater_than(0).only_integer }

    it { is_expected.to validate_numericality_of(:bit_rate_bps).is_greater_than(0).only_integer }

    it { is_expected.to validate_presence_of(:media_type) }

    it { is_expected.to validate_presence_of(:data_length_bytes) }
    it { is_expected.to validate_numericality_of(:data_length_bytes).is_greater_than(0).only_integer }

    it { is_expected.to validate_presence_of(:file_hash) }
    it { is_expected.to validate_length_of(:file_hash).is_equal_to(72) }
    it { is_expected.to validate_uniqueness_of(:file_hash).case_insensitive.on(:create) }
    it { is_expected.not_to allow_value('a' * 72).for(:file_hash) }

    # .with_predicates(true).with_multiple(false)
    it { is_expected.to enumerize(:status).in(*AudioRecording::AVAILABLE_STATUSES) }
  end

  context 'in same site' do
    it 'allows non overlapping dates - (first before second)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:03+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows non overlapping dates - (second before first)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:03+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'does not allow overlapping dates - exact' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(60.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('no overlap or recordings overlap completely')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # can fix is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'does not allow overlapping dates - shift forwards' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:48+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:04+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(16.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of existing, end of new')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # fixed is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'does not allow overlapping dates - shift forwards (overlap both ends)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 30.0, recorded_date: '2014-02-07T17:50:20+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:10+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(30.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('no overlap or recordings overlap completely')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # can fix is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'does not allow overlapping dates - shift backwards' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:04+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:48+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(16.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of new, end of existing')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # fixed is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'does not allow overlapping dates - shift backwards (1 sec overlap)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:59+10:00',
        site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_truthy
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(1.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of new, end of existing')
      expect(result[:overlap][:items][0][:can_fix]).to be_truthy

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar1.id).notes[:duration_adjustment_for_overlap].size).to eq(1)
      expect(AudioRecording.find(ar1.id).notes[:duration_adjustment_for_overlap][0][:overlap_amount]).to eq(1.0)
      expect(AudioRecording.find(ar1.id).notes[:duration_adjustment_for_overlap][0][:old_duration]).to eq(60.0)
      expect(AudioRecording.find(ar1.id).notes[:duration_adjustment_for_overlap][0][:new_duration]).to eq(59.0)
      expect(AudioRecording.find(ar1.id).notes[:duration_adjustment_for_overlap][0][:other_uuid]).to eq(ar2.uuid)

      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows overlapping dates - edges exact (first before second)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00',
        site_id: 1001)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows overlapping dates - edges exact (second before first)' do
      create(:site, id: 1001)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00',
        site_id: 1001)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end
  end

  context 'in different sites' do
    it 'allows overlapping dates - exact' do
      create(:site, id: 1001)
      create(:site, id: 1002)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows overlapping dates - shift forwards' do
      create(:site, id: 1001)
      create(:site, id: 1002)
      ar1 = create(:audio_recording, duration_seconds: 30.0, recorded_date: '2014-02-07T17:50:20+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:10+10:00',
        site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows overlapping dates - shift backwards' do
      create(:site, id: 1001)
      create(:site, id: 1002)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:30+10:00',
        site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end

    it 'allows overlapping dates - edges exact' do
      create(:site, id: 1001)
      create(:site, id: 1002)
      ar1 = create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00',
        site_id: 1001)
      ar2 = build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00',
        site_id: 1002)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).not_to include(:duration_adjustment_for_overlap)
      expect(AudioRecording.find(ar2.id).notes).not_to include(:duration_adjustment_for_overlap)
    end
  end

  it 'does not allow duplicate files' do
    file_hash = MiscHelper.new.create_sha_256_hash('c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891')
    create(:audio_recording, file_hash:)
    expect(build(:audio_recording, file_hash:)).not_to be_valid
  end

  it 'does not allow audio recordings shorter than minimum duration' do
    expect {
      create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec - 1)
    }.to raise_error(ActiveRecord::RecordInvalid,
      /Validation failed: Duration seconds must be greater than or equal to #{Settings.audio_recording_min_duration_sec}.*/)
  end

  it 'allows audio recordings equal to than minimum duration' do
    ar = build(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar).to be_valid
  end

  it 'allows audio recordings longer than minimum duration' do
    ar = create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec + 1)
    expect(ar).to be_valid
  end

  it 'allows data_length_bytes of more than int32 max' do
    create(:audio_recording, data_length_bytes: 2_147_483_648)
  end

  it '(temporarily)s allow duplicate empty file hash to be updated to real hash' do
    ar1 = build(:audio_recording, uuid: UUIDTools::UUID.random_create.to_s, file_hash: 'SHA256::')
    ar1.save(validate: false)

    ar2 = build(:audio_recording, uuid: UUIDTools::UUID.random_create.to_s, file_hash: 'SHA256::')
    ar2.save(validate: false)

    ar2.file_hash = MiscHelper.new.create_sha_256_hash
    ar2.save!
  end

  it 'provides a hash split function to return the file_hash components' do
    ar = build(:audio_recording, file_hash: 'SHA256::abc123')

    protocol, value = ar.split_file_hash

    expect(protocol).to eq('SHA256')
    expect(value).to eq('abc123')

    expect {
      ar = build(:audio_recording, file_hash: 'SHA256::abc::123')
      ar.split_file_hash
    }.to raise_error(RuntimeError, 'Invalid file hash detected (more than one "::" found)')
  end

  it 'can return a canonical filename for an audio recording' do
    uuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

    ar = build(:audio_recording, uuid:, media_type: 'audio/wav')

    actual = ar.canonical_filename

    expect(actual).to eq("#{uuid}.wav")
  end

  describe 'friendly names' do
    let!(:site) { create(:site) }
    let!(:audio_recording) { create(:audio_recording, site:) }

    [
      # mime, extension
      ['audio/mpeg', 'mp3'],
      ['audio/mp3', 'mp3'],
      ['audio/x-wv', 'wv'],
      ['audio/x-ms-wma', 'asf'],
      ['audio/x-flac', 'flac'],
      ['audio/flac', 'flac'],
      ['video/x-ms-asf', 'asf'],
      ['audio/x-wav', 'wav'],
      ['audio/wav', 'wav']
    ].each do |mime, extension|
      [
        # site name, timezone, date, expected
        ["Ant's super cool site", 'Australia/Brisbane', Time.parse('2018-02-26T12:29:30Z'),
         '20180226T222930+1000_Ants-super-cool-site_%<audio_recording_id>s.%<extension>s'],
        ['Ants super cool site', nil, Time.parse('2018-02-26T12:29:30Z'),
         '20180226T122930Z_Ants-super-cool-site_%<audio_recording_id>s.%<extension>s'],
        ['bZ_20', 'America/Chicago', Time.parse('2018-02-26T12:29:30Z'),
         '20180226T062930-0600_bZ_20_%<audio_recording_id>s.%<extension>s'],
        ['!@#@$%', 'UTC', Time.parse('2018-02-26T12:29:30Z'),
         '20180226T122930Z_NONAME_%<audio_recording_id>s.%<extension>s'],
        ['TesTing-This', 'Australia/Perth', Time.parse('2018-02-26T12:29:30Z'),
         '20180226T202930+0800_TesTing-This_%<audio_recording_id>s.%<extension>s']
        # TODO: dst example
      ].each do |site_name, timezone, date, expected|
        describe "for mime: #{mime}, expected: #{expected}" do
          let(:expected_formatted) { format(expected, audio_recording_id: audio_recording.id, extension:) }

          before do
            site.name = site_name
            site.tzinfo_tz = timezone
            site.save!

            audio_recording.recorded_date = date
            audio_recording.media_type = mime
            audio_recording.save!
          end

          it 'can return a friendly file name for an audio recording' do
            actual = audio_recording.friendly_name

            expect(actual).to eq(expected_formatted)
          end

          it 'has a friendly name AREL equivalent' do
            actual = AudioRecording.where(id: audio_recording.id).pick(AudioRecording::FRIENDLY_NAME_AREL)

            expect(actual).to eq(expected_formatted)
          end
        end
      end
    end

    it 'has a friendly name regex' do
      match = AudioRecording::FRIENDLY_NAME_REGEX.match('20180226T222930+1000_Ants-super-cool-site_123456.wav')

      expect(match).not_to be_nil
      expect(match[:date]).to eq '20180226T222930+1000'
      expect(match[:site_name]).to eq 'Ants-super-cool-site'
      expect(match[:id]).to eq '123456'
      expect(match[:extension]).to eq 'wav'
    end

    it 'has a friendly name regex (parses Z as well)' do
      match = AudioRecording::FRIENDLY_NAME_REGEX.match('20180226T122930Z_Ants-super-cool-site_123456.wav')

      expect(match).not_to be_nil
      expect(match[:date]).to eq '20180226T122930Z'
      expect(match[:site_name]).to eq 'Ants-super-cool-site'
      expect(match[:id]).to eq '123456'
      expect(match[:extension]).to eq 'wav'
    end
  end

  it_behaves_like 'cascade deletes for', :audio_recording, {
    audio_events: {
      taggings: nil,
      comments: nil,
      verifications: nil
    },
    analysis_jobs_items: :audio_event_import_files,
    bookmarks: nil,
    dataset_items: {
      progress_events: nil,
      responses: nil
    },
    harvest_item: nil,
    statistics: nil
  } do
    create_entire_hierarchy
  end
end
