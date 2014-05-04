require 'spec_helper'

describe AudioRecording do
  it 'has a valid factory' do
    ar = create(:audio_recording,
                recorded_date: Time.zone.now.advance(seconds: -20),
                file_hash: '1111',
                duration_seconds: Settings.audio_recording_min_duration_sec)
    ar.should be_valid
  end
  it 'has a valid FactoryGirl factory' do
    ar = FactoryGirl.create(:audio_recording,
                            recorded_date: Time.zone.now.advance(seconds: -10),
                            file_hash: '2222',
                            duration_seconds: Settings.audio_recording_min_duration_sec)
    ar.should be_valid
  end
  it 'has a valid FactoryGirl factory' do
    ar = FactoryGirl.create(:audio_recording)
    ar.should be_valid

  end
  it 'creating it with a nil :uuid will regenerate one anyway' do
    # so because it is auto generated, setting :uuid to nil won't work here
    FactoryGirl.build(:audio_recording, uuid: nil).should be_valid
  end
  it 'is invalid without a uuid' do
    ar = FactoryGirl.create(:audio_recording)
    ar.uuid = nil
    ar.should_not be_valid
  end

  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }
  it { should belong_to(:deleter).with_foreign_key(:deleter_id) }
  it { should belong_to(:uploader).with_foreign_key(:uploader_id) }

  it { should belong_to(:site) }
  it { should have_many(:audio_events) }
  it { should validate_presence_of(:uploader_id) }
  it { should_not allow_value(nil).for(:uploader_id) }

  it { should validate_presence_of(:recorded_date) }
  it { should_not allow_value(7.days.from_now).for(:recorded_date) }
  it { should_not allow_value(3.0).for(:recorded_date) }

  it { should validate_presence_of(:duration_seconds) }
  it { should validate_numericality_of(:duration_seconds) }
  it { should_not allow_value(-1).for(:duration_seconds) }
  it { should allow_value(Settings.audio_recording_min_duration_sec).for(:duration_seconds) }
  it { should_not allow_value(Settings.audio_recording_min_duration_sec - 0.5).for(:duration_seconds) }
  it { should_not allow_value(0).for(:duration_seconds) }

  it { should validate_numericality_of(:sample_rate_hertz) }
  it { should_not allow_value(-1).for(:sample_rate_hertz) }
  it { should_not allow_value(0).for(:sample_rate_hertz) }
  it { should_not allow_value(5.32).for(:sample_rate_hertz) }

  it { should validate_numericality_of(:channels) }
  it { should_not allow_value(-1).for(:channels) }
  it { should_not allow_value(0).for(:channels) }
  it { should_not allow_value(5.32).for(:channels) }
  it { should_not allow_value(5.00).for(:channels) }
  it { should allow_value(5).for(:channels) }

  it { should validate_numericality_of(:bit_rate_bps) }
  it { should_not allow_value(-1).for(:bit_rate_bps) }
  it { should_not allow_value(0).for(:bit_rate_bps) }
  it { should_not allow_value(5.32).for(:bit_rate_bps) }
  it { should_not allow_value(5.00).for(:bit_rate_bps) }
  it { should allow_value(5).for(:bit_rate_bps) }

  it { should validate_presence_of(:media_type) }
  it { should validate_presence_of(:data_length_bytes) }
  it { should validate_numericality_of(:data_length_bytes) }
  it { should_not allow_value(-1).for(:data_length_bytes) }
  it { should_not allow_value(0).for(:data_length_bytes) }
  it { should_not allow_value(5.32).for(:data_length_bytes) }

  it { should validate_presence_of(:file_hash) }

  context 'in same site' do

    it 'should allow non overlapping dates - (first before second)' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:51:03+10:00", site_id: 1001, file_hash: "2")
      ar2.should be_valid
    end

    it 'should allow non overlapping dates - (second before first)' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:51:03+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "2")
      ar2.should be_valid
    end

    it 'should not allow overlapping dates - exact' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "2")
      ar2.should_not be_valid
    end
    it 'should not allow overlapping dates - shift forwards' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 30.0, recorded_date: "2014-02-07T17:50:20+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:10+10:00", site_id: 1001, file_hash: "2")
      ar2.should_not be_valid
    end

    it 'should not allow overlapping dates - shift backwards' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:04+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:48+10:00", site_id: 1001, file_hash: "2")
      ar2.should_not be_valid
    end

    it 'should not allow overlapping dates - shift backwards (1 sec overlap)' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:00+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:59+10:00", site_id: 1001, file_hash: "2")
      ar2.should_not be_valid
    end

    it 'should allow overlapping dates - edges exact (first before second)' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:00+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:51:00+10:00", site_id: 1001, file_hash: "2")
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:51:00+10:00"))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:52:00+10:00"))
      ar2.should be_valid
    end

    it 'should allow overlapping dates - edges exact (second before first)' do
      site = FactoryGirl.create(:site, id: 1001)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:51:00+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:00+10:00", site_id: 1001, file_hash: "2")
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:52:00+10:00"))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:51:00+10:00"))
      ar2.should be_valid
    end

  end

  context 'in different sites' do
    it 'should allow overlapping dates - exact' do
      FactoryGirl.create(:site, id: 1001)
      FactoryGirl.create(:site, id: 1002)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1002, file_hash: "2")
      ar2.should be_valid
    end
    it 'should allow overlapping dates - shift forwards' do
      FactoryGirl.create(:site, id: 1001)
      FactoryGirl.create(:site, id: 1002)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 30.0, recorded_date: "2014-02-07T17:50:20+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:10+10:00", site_id: 1002, file_hash: "2")
      ar2.should be_valid
    end
    it 'should allow overlapping dates - shift backwards' do
      FactoryGirl.create(:site, id: 1001)
      FactoryGirl.create(:site, id: 1002)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:30+10:00", site_id: 1002, file_hash: "2")
      ar2.should be_valid
    end

    it 'should allow overlapping dates - edges exact' do
      FactoryGirl.create(:site, id: 1001)
      FactoryGirl.create(:site, id: 1002)
      ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:00+10:00", site_id: 1001, file_hash: "1")
      ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:51:00+10:00", site_id: 1002, file_hash: "2")
      expect(ar1.recorded_date.advance(seconds: ar1.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:51:00+10:00"))
      expect(ar2.recorded_date.advance(seconds: ar2.duration_seconds)).to eq(Time.zone.parse("2014-02-07T17:52:00+10:00"))
      ar2.should be_valid
    end
  end

  it 'should not allow duplicate files' do
    file_hash = "SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891"
    FactoryGirl.create(:audio_recording, file_hash: file_hash)
    FactoryGirl.build(:audio_recording, file_hash: file_hash).should_not be_valid
  end

  it 'should not allow audio recordings shorter than minimum duration' do
    expect {
      FactoryGirl.create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec - 1)
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Duration seconds must be greater than or equal to #{Settings.audio_recording_min_duration_sec}")
  end

  it 'should allow audio recordings equal to than minimum duration' do
    ar = FactoryGirl.build(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec)
    expect(ar.valid?).to be_true
  end

  it 'should allow audio recordings longer than minimum duration' do
    ar = FactoryGirl.create(:audio_recording, duration_seconds: Settings.audio_recording_min_duration_sec + 1)
    expect(ar.valid?).to be_true
  end
end