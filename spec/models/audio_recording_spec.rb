# frozen_string_literal: true

require 'rails_helper'

describe AudioRecording, type: :model do
  it 'has a valid factory' do
    ar = create(:audio_recording,
                recorded_date: Time.zone.now.advance(seconds: -20),
                duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar).to be_valid
  end
  it 'has a valid FactoryBot factory' do
    ar = FactoryBot.create(:audio_recording,
                           recorded_date: Time.zone.now.advance(seconds: -10),
                           duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar).to be_valid
  end
  it 'has a valid FactoryBot factory' do
    ar = FactoryBot.create(:audio_recording)
    expect(ar).to be_valid
  end

  it 'creating it with a nil :uuid will not generate one on validation' do
    # so because it is auto generated, setting :uuid to nil won't work here
    expect(FactoryBot.build(:audio_recording, uuid: nil)).not_to be_valid
  end
  it 'is invalid without a uuid' do
    ar = FactoryBot.create(:audio_recording)
    ar.uuid = nil
    expect(ar.save).to be_falsey
    expect(ar).not_to be_valid
  end

  it 'has a uuid when created' do
    ar = FactoryBot.build(:audio_recording)
    expect(ar.uuid).not_to be_nil
  end

  it 'has same uuid before and after saved to db' do
    ar = FactoryBot.build(:audio_recording)
    uuid_before = ar.uuid
    expect(ar).to be_valid
    expect(ar.uuid).to_not be_nil

    ar.save!
    uuid_after = ar.uuid
    expect(uuid_after).to eq(uuid_before)
  end

  it 'fails validation when uploader is nil' do
    test_item = FactoryBot.build(:audio_recording)
    test_item.uploader = nil

    expect(subject.valid?).to be_falsey
    expect(subject.errors[:uploader].size).to eq(1)
    expect(subject.errors[:uploader].to_s).to match(/must exist/)
  end

  context 'validation' do
    subject { FactoryBot.build(:audio_recording) }

    it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
    it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
    it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id).optional }
    it { is_expected.to belong_to(:uploader).with_foreign_key(:uploader_id) }

    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:audio_events) }
    it { is_expected.to have_many(:bookmarks) }
    it { is_expected.to have_many(:tags) }

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
    it { is_expected.to validate_numericality_of(:duration_seconds).is_greater_than_or_equal_to(Settings.audio_recording_min_duration_sec) }
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
    it 'should allow non overlapping dates - (first before second)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:03+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow non overlapping dates - (second before first)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:03+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should not allow overlapping dates - exact' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(60.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('no overlap or recordings overlap completely')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # can fix is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should not allow overlapping dates - shift forwards' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:48+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:04+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(16.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of existing, end of new')
      expect(result[:overlap][:items][0][:can_fix]).to be_truthy

      # fixed is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should not allow overlapping dates - shift forwards (overlap both ends)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 30.0, recorded_date: '2014-02-07T17:50:20+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:10+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(30.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('no overlap or recordings overlap completely')
      expect(result[:overlap][:items][0][:can_fix]).to be_falsey

      # can fix is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should not allow overlapping dates - shift backwards' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:04+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:48+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_falsey
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(16.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of new, end of existing')
      expect(result[:overlap][:items][0][:can_fix]).to be_truthy

      # fixed is false
      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should not allow overlapping dates - shift backwards (1 sec overlap)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:59+10:00', site_id: 1001)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(1)
      expect(result[:overlap][:items].size).to eq(1)
      expect(result[:overlap][:items][0][:fixed]).to be_truthy
      expect(result[:overlap][:items][0][:overlap_amount]).to eq(1.0)
      expect(result[:overlap][:items][0][:overlap_location]).to eq('start of new, end of existing')
      expect(result[:overlap][:items][0][:can_fix]).to be_truthy

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar1.id).notes['duration_adjustment_for_overlap'].size).to eq(1)
      expect(AudioRecording.find(ar1.id).notes['duration_adjustment_for_overlap'][0]['overlap_amount']).to eq(1.0)
      expect(AudioRecording.find(ar1.id).notes['duration_adjustment_for_overlap'][0]['old_duration']).to eq(60.0)
      expect(AudioRecording.find(ar1.id).notes['duration_adjustment_for_overlap'][0]['new_duration']).to eq(59.0)
      expect(AudioRecording.find(ar1.id).notes['duration_adjustment_for_overlap'][0]['other_uuid']).to eq(ar2.uuid)

      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow overlapping dates - edges exact (first before second)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00', site_id: 1001)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow overlapping dates - edges exact (second before first)' do
      site = FactoryBot.create(:site, id: 1001)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00', site_id: 1001)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end
  end

  context 'in different sites' do
    it 'should allow overlapping dates - exact' do
      FactoryBot.create(:site, id: 1001)
      FactoryBot.create(:site, id: 1002)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow overlapping dates - shift forwards' do
      FactoryBot.create(:site, id: 1001)
      FactoryBot.create(:site, id: 1002)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 30.0, recorded_date: '2014-02-07T17:50:20+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:10+10:00', site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow overlapping dates - shift backwards' do
      FactoryBot.create(:site, id: 1001)
      FactoryBot.create(:site, id: 1002)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:03+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:30+10:00', site_id: 1002)

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end

    it 'should allow overlapping dates - edges exact' do
      FactoryBot.create(:site, id: 1001)
      FactoryBot.create(:site, id: 1002)
      ar1 = FactoryBot.create(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:50:00+10:00', site_id: 1001)
      ar2 = FactoryBot.build(:audio_recording, duration_seconds: 60.0, recorded_date: '2014-02-07T17:51:00+10:00', site_id: 1002)
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:51:00+10:00'))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse('2014-02-07T17:52:00+10:00'))

      result = ar2.fix_overlaps
      expect(result[:overlap][:count]).to eq(0)
      expect(result[:overlap][:items]).to be_empty

      ar2.save!
      expect(AudioRecording.find(ar1.id).notes).to_not include('duration_adjustment_for_overlap')
      expect(AudioRecording.find(ar2.id).notes).to_not include('duration_adjustment_for_overlap')
    end
  end

  it 'should not allow duplicate files' do
    file_hash = MiscHelper.new.create_sha_256_hash('c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891')
    FactoryBot.create(:audio_recording, file_hash: file_hash)
    expect(FactoryBot.build(:audio_recording, file_hash: file_hash)).not_to be_valid
  end

  it 'should not allow audio recordings shorter than minimum duration' do
    expect {
      FactoryBot.create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec - 1)
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Duration seconds must be greater than or equal to #{Settings.audio_recording_min_duration_sec}")
  end

  it 'should allow audio recordings equal to than minimum duration' do
    ar = FactoryBot.build(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar.valid?).to be_truthy
  end

  it 'should allow audio recordings longer than minimum duration' do
    ar = FactoryBot.create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec + 1)
    expect(ar.valid?).to be_truthy
  end

  it 'should allow data_length_bytes of more than int32 max' do
    FactoryBot.create(:audio_recording, data_length_bytes: 2_147_483_648)
  end

  it 'should (temporarily) allow duplicate empty file hash to be updated to real hash' do
    ar1 = FactoryBot.build(:audio_recording, uuid: UUIDTools::UUID.random_create.to_s, file_hash: 'SHA256::')
    ar1.save(validate: false)

    ar2 = FactoryBot.build(:audio_recording, uuid: UUIDTools::UUID.random_create.to_s, file_hash: 'SHA256::')
    ar2.save(validate: false)

    ar2.file_hash = MiscHelper.new.create_sha_256_hash
    ar2.save!
  end

  it 'provides a hash split function to return the file_hash components' do
    ar = FactoryBot.build(:audio_recording, file_hash: 'SHA256::abc123')

    protocol, value = ar.split_file_hash

    expect(protocol).to eq('SHA256')
    expect(value).to eq('abc123')

    expect {
      ar = FactoryBot.build(:audio_recording, file_hash: 'SHA256::abc::123')
      ar.split_file_hash
    }.to raise_error(RuntimeError, 'Invalid file hash detected (more than one "::" found)')
  end

  it 'can return a canonical filename for an audio recording' do
    uuid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    date = '20180226-222930Z'

    ar = FactoryBot.build(:audio_recording, uuid: uuid, recorded_date: DateTime.strptime(date, '%Y%m%d-%H%M%S%z'), media_type: 'audio/wav')

    actual = ar.canonical_filename

    expect(actual).to eq("#{uuid}_#{date}.wav")
  end
end
