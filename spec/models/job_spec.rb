require 'spec_helper'


describe Job do
  it 'has a valid factory' do
    create(:job).should be_valid
  end
  #it {should have_many(:analysis_items)}

  it { should validate_presence_of(:name) }
  it 'is invalid without a name' do
    build(:job, name: nil).should_not be_valid
  end
  it 'should ensure the name is no more than 255 characters' do
    test_string = Faker::Lorem.characters(256)
    build(:job, name: test_string).should_not be_valid
    build(:job, name: test_string[0..-2]).should be_valid
  end
  it 'should ensure name is unique  (case-insensitive)' do
    create(:job, name: 'There ain\'t room enough in this town for two of us sonny!')
    as2 = build(:job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!')
    as2.should_not be_valid
    as2.should have(1).error_on(:name)
  end

  it { should validate_presence_of(:script_settings) }
  it 'is invalid without a script_settings' do
    build(:job, script_settings: nil).should_not be_valid
  end

  it { should validate_presence_of(:dataset_id) }
  it 'is invalid without a dataset' do
    build(:job, dataset_id: nil).should_not be_valid
  end
  it { should validate_presence_of(:script_id) }
  it 'is invalid without a script' do
    build(:job, script_id: nil).should_not be_valid
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