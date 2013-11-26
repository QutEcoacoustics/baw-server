require 'spec_helper'

describe AudioRecording do
  it 'has a valid factory' do
    ar = create(:audio_recording)
    ar.should be_valid

  end
  it 'creating it with a nil :uuid will regenerate one anyway' do
    # so because it is auto generated, setting :uuid to nil won't work here
    FactoryGirl.build(:audio_recording, :uuid => nil).should be_valid
  end
  it 'is invalid without an uuid' do
    ar = FactoryGirl.create(:audio_recording)
    ar.uuid = nil
    ar.should_not be_valid
  end
  it { should belong_to(:site)}
  it { should have_many(:audio_events)}
  it { should validate_presence_of(:uploader_id) }
  it 'requires uploader_id to be set' do
    build(:audio_recording, :uploader_id => nil)
  end
  it { should validate_presence_of(:recorded_date) }
  it 'should not have a recorded date that is in the future' do
    build(:audio_recording, :recorded_date => 7.days.from_now ).should_not be_valid
  end
  it 'should have a valid date' do
    build(:audio_recording, :recorded_date => 3.0).should_not be_valid
  end
  it { should validate_presence_of(:duration_seconds)}
  it { should validate_numericality_of(:duration_seconds) }
  it { should_not allow_value(-1  ).for(:duration_seconds)}
  it 'should not allow a value of zero for duration_seconds' do
    build(:audio_recording, duration_seconds: 0).should be_valid
  end
  it { should validate_numericality_of(:sample_rate_hertz) }
  it { should_not allow_value(-1  ).for(:sample_rate_hertz)}
  it 'should not allow a value of zero for sample_rate_hertz' do
    build(:audio_recording, sample_rate_hertz: 0).should be_valid
  end
  it { should_not allow_value(5.32).for(:sample_rate_hertz)}
  it { should validate_numericality_of(:channels) }
  it { should_not allow_value(-1  ).for(:channels)}
  it 'should not allow a value of zero for channels' do
    build(:audio_recording, channels: 0).should_not be_valid
  end
  it { should_not allow_value(5.32).for(:channels)}
  it { should validate_numericality_of(:bit_rate_bps) }
  it { should_not allow_value(-1  ).for(:bit_rate_bps)}
  it 'should not allow a value of zero for bit_rate_bps' do
    build(:audio_recording, bit_rate_bps: 0).should be_valid
  end
  it { should_not allow_value(5.32).for(:bit_rate_bps)}
  it { should validate_presence_of(:media_type)}
  it { should validate_presence_of(:data_length_bytes)}
  it { should validate_numericality_of(:data_length_bytes) }
  it { should_not allow_value(-1  ).for(:data_length_bytes)}
  it 'should not allow a value of zero for data_length_bytes' do
    build(:audio_recording, data_length_bytes: 0).should be_valid
  end
  it { should_not allow_value(5.32).for(:data_length_bytes)}
  it { should validate_presence_of(:file_hash)}

end