require 'spec_helper'


describe Job, :type => :model do
  it 'has a valid factory' do
    expect(create(:job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { is_expected.to validate_presence_of(:name) }
  it 'is invalid without a name' do
    expect(build(:job, name: nil)).not_to be_valid
  end
  it 'should ensure the name is no more than 255 characters' do
    test_string = 'a' * 256
    expect(build(:job, name: test_string)).not_to be_valid
    expect(build(:job, name: test_string[0..-2])).to be_valid
  end
  it 'should ensure name is unique  (case-insensitive)' do
    create(:job, name: 'There ain\'t room enough in this town for two of us sonny!')
    as2 = build(:job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!')
    expect(as2).not_to be_valid
    expect(as2.valid?).to be_falsey
    expect(as2.errors[:name].size).to eq(1)
  end

  it 'fails validation when dataset is nil' do
    test_item = FactoryGirl.build(:job)
    test_item.dataset = nil

    expect(subject.valid?).to be_falsey
    expect(subject.errors[:dataset].size).to eq(1)
    expect(subject.errors[:dataset].to_s).to match(/must exist as an object or foreign key/)
  end

  it 'fails validation when script is nil' do
    test_item = FactoryGirl.build(:job)
    test_item.script = nil

    expect(subject.valid?).to be_falsey
    expect(subject.errors[:script].size).to eq(1)
    expect(subject.errors[:script].to_s).to match(/must exist as an object or foreign key/)
  end
  
  it { is_expected.to validate_presence_of(:script_settings) }
  it 'is invalid without a script_settings' do
    expect(build(:job, script_settings: nil)).not_to be_valid
  end


  it 'is invalid without a dataset' do
    expect(build(:job, dataset_id: nil)).not_to be_valid
  end

  it 'is invalid without a script' do
    expect(build(:job, script_id: nil)).not_to be_valid
  end

  #
  #it 'should be valid without a process_new field specified' do
  #  build(:job, process_new: nil).should be_valid
  #end
  #it 'ensures process_new can be true or false' do
  #  as = build(:job)
  #  as.should be_valid
  #  as.process_new = true
  #  as.should be_valid
  #  as.process_new = false
  #  as.should be_valid
  #end

  #context 'should ensure that process_new and data_set_identifier are mutually exclusive' do
  #  # 6 cases to consider
  #  cases =
  #      [
  #          {pn: true, dsi: nil, result: true},
  #          {pn: false, dsi: nil, result: true},
  #          {pn: nil, dsi: nil, result: true},
  #          {pn: true, dsi: "hello", result: false},
  #          {pn: false, dsi: "my", result: true},
  #          {pn: nil, dsi: "name is barney the dinosaur", result: true}
  #      ]
  #  cases.each { |testcase|
  #    it "should ensure that with {process_new:#{testcase[:pn]}, data_set_identifier:#{testcase[:dsi]}} should be #{'not' if !testcase[:result]} valid" do
  #      if testcase[:result]
  #        build(:job, {process_new: testcase[:pn], data_set_identifier:testcase[:dsi]}).should be_valid
  #      else
  #        build(:job, {process_new: testcase[:pn], data_set_identifier:testcase[:dsi]}).should_not be_valid
  #      end
  #
  #    end
  #  }
  #
  #end


end