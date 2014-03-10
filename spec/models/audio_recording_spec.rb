require 'spec_helper'

describe AudioRecording do
  it 'has a valid factory' do
    ar = create(:audio_recording, recorded_date: Time.zone.now.advance(seconds:-20), file_hash: '1111', duration_seconds: 5)
    ar.should be_valid
  end
  it 'has a valid FactoryGirl factory' do
    ar = FactoryGirl.create(:audio_recording, recorded_date: Time.zone.now.advance(seconds:-10), file_hash: '2222', duration_seconds: 5)
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
  it { should belong_to(:site) }
  it { should have_many(:audio_events) }
  it { should validate_presence_of(:uploader_id) }
  it { should_not allow_value(nil).for(:uploader_id) }

  it { should validate_presence_of(:recorded_date) }
  it { should_not allow_value(7.days.from_now).for(:recorded_date) }
  it { should_not allow_value(3.0).for(:recorded_date) }

  it { should validate_presence_of(:duration_seconds)}
  it { should validate_numericality_of(:duration_seconds) }
  it { should_not allow_value(-1).for(:duration_seconds)}
  it { should allow_value(1).for(:duration_seconds)}
  it { should_not allow_value(0).for(:duration_seconds)}

  it { should validate_numericality_of(:sample_rate_hertz) }
  it { should_not allow_value(-1  ).for(:sample_rate_hertz)}
  it { should_not allow_value(0).for(:sample_rate_hertz)}
  it { should_not allow_value(5.32).for(:sample_rate_hertz)}

  it { should validate_numericality_of(:channels) }
  it { should_not allow_value(-1).for(:channels)}
  it { should_not allow_value(0).for(:channels)}
  it { should_not allow_value(5.32).for(:channels)}
  it { should_not allow_value(5.00).for(:channels)}
  it { should allow_value(5).for(:channels)}

  it { should validate_numericality_of(:bit_rate_bps) }
  it { should_not allow_value(-1).for(:bit_rate_bps)}
  it { should_not allow_value(0).for(:bit_rate_bps)}
  it { should_not allow_value(5.32).for(:bit_rate_bps)}
  it { should_not allow_value(5.00).for(:bit_rate_bps)}
  it { should allow_value(5).for(:bit_rate_bps)}

  it { should validate_presence_of(:media_type)}
  it { should validate_presence_of(:data_length_bytes)}
  it { should validate_numericality_of(:data_length_bytes) }
  it { should_not allow_value(-1).for(:data_length_bytes)}
  it { should_not allow_value(0).for(:data_length_bytes)}
  it { should_not allow_value(5.32).for(:data_length_bytes)}

  it { should validate_presence_of(:file_hash)}

  it 'should not allow overlapping dates in the same site - exact' do
    site = FactoryGirl.create(:site, id: 1001)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "2")
    ar2.should_not be_valid
  end
  it 'should not allow overlapping dates in the same site - shift forwards' do
    site = FactoryGirl.create(:site, id: 1001)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 30.0, recorded_date: "2014-02-07T17:50:20+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:10+10:00", site_id: 1001, file_hash: "2")
    ar2.should_not be_valid
  end
  it 'should not allow overlapping dates in the same site - shift backwards' do
    site = FactoryGirl.create(:site, id: 1001)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:30+10:00", site_id: 1001, file_hash: "2")
    ar2.should_not be_valid
  end
  it 'should allow overlapping dates in the different sites - exact' do
    site = FactoryGirl.create(:site, id: 1001)
    site = FactoryGirl.create(:site, id: 1002)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1002, file_hash: "2")
    ar2.should be_valid
  end
  it 'should allow overlapping dates in the different site - shift forwards' do
    site = FactoryGirl.create(:site, id: 1001)
    site = FactoryGirl.create(:site, id: 1002)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 30.0, recorded_date: "2014-02-07T17:50:20+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:10+10:00", site_id: 1002, file_hash: "2")
    ar2.should be_valid
  end
  it 'should allow overlapping dates in the different sites - shift backwards' do
    site = FactoryGirl.create(:site, id: 1001)
    site = FactoryGirl.create(:site, id: 1002)
    ar1 = FactoryGirl.create(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:03+10:00", site_id: 1001, file_hash: "1")
    ar2 = FactoryGirl.build(:audio_recording, duration_seconds: 60.0, recorded_date: "2014-02-07T17:50:30+10:00", site_id: 1002, file_hash: "2")
    ar2.should be_valid
  end
  it 'should not allow duplicate files' do
    file_hash = "SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891"
    FactoryGirl.create(:audio_recording, file_hash: file_hash)
    FactoryGirl.build(:audio_recording, file_hash: file_hash).should_not be_valid
  end
end