require 'spec_helper'

describe AnalysisJob, type: :model do
  it 'has a valid factory' do
    expect(create(:analysis_job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { is_expected.to validate_presence_of(:name) }
  it 'is invalid without a name' do
    expect(build(:analysis_job, name: nil)).not_to be_valid
  end
  it 'should ensure the name is no more than 255 characters' do
    test_string = 'a' * 256
    expect(build(:analysis_job, name: test_string)).not_to be_valid
    expect(build(:analysis_job, name: test_string[0..-2])).to be_valid
  end
  it 'should ensure name is unique  (case-insensitive)' do
    create(:analysis_job, name: 'There ain\'t room enough in this town for two of us sonny!')
    as2 = build(:analysis_job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!')
    expect(as2).not_to be_valid
    expect(as2.valid?).to be_falsey
    expect(as2.errors[:name].size).to eq(1)
  end

  it 'fails validation when script is nil' do
    test_item = FactoryGirl.build(:analysis_job)
    test_item.script = nil

    expect(subject.valid?).to be_falsey
    expect(subject.errors[:script].size).to eq(1)
    expect(subject.errors[:script].to_s).to match(/must exist as an object or foreign key/)
  end
  
  it { is_expected.to validate_presence_of(:custom_settings) }
  it 'is invalid without a custom_settings' do
    expect(build(:analysis_job, custom_settings: nil)).not_to be_valid
  end

  it 'is invalid without a script' do
    expect(build(:analysis_job, script_id: nil)).not_to be_valid
  end

  it 'is invalid without a saved_search' do
    expect(build(:analysis_job, saved_search: nil)).not_to be_valid
  end

end