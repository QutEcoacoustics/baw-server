require 'spec_helper'

describe Dataset do
  it 'has a valid factory' do
    create(:dataset).should be_valid
  end
  #it { should have_many(:progresses) }
  it { should belong_to(:creator).with_foreign_key(:creator_id) }


  it 'should not allow duplicate names for the same user (case-insensitive)' do
    create(:dataset, {creator_id: 3, name: 'I love the smell of napalm in the morning.'})
    ss = build(:dataset, {creator_id: 3, name: 'I LOVE the smell of napalm in the morning.'})
    ss.should_not be_valid
    ss.should have(1).error_on(:name)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    ss.should be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    ss1 = create(:dataset, {creator_id: 3, name: 'You talkin\' to me?'})

    ss2 = build(:dataset, {creator_id: 1, name: 'You TALKIN\' to me?'})
    ss2.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss2.should be_valid

    ss3 = build(:dataset, {creator_id: 2, name: 'You talkin\' to me?'})
    ss3.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss3.should be_valid
  end


  #context "States (different types of search)" do
  #  cases = [
  #      ["Jason farts", true, 'explicit_personal?'],
  #      [nil, true, 'implicit_personal?'],
  #      ["Jason farts", false, 'explicit_global?'],
  #      [nil, false, 'implicit_global?']
  #  ]
  #  cases.each { |test_case|
  #    it "is valid if name is '#{test_case[0]}' and user id is #{"not" if test_case[1]} blank" do
  #
  #      if test_case[1]
  #        ss = build(:dataset, name:test_case[0])
  #      else
  #        ss = build(:dataset_base, name:test_case[0])
  #      end
  #
  #      ss.send(test_case[2]).should == true
  #
  #      ss.should be_valid
  #    end
  #  }
  #end
  #


  #it 'should not allow duplicate names for global searches (case-sensitive)' do
  #  create(:dataset, {creator_id:nil, name: 'May the Force be with you.' })
  #  ss = build(:dataset,  {creator_id:nil, name: 'May the Force be with you.' })
  #  ss.should_not be_valid
  #  ss.should have(1).error_on(:name)
  #
  #  ss.name =  'May the FORCE be with you.'
  #  ss.should be_valid
  #end

  #it { should validate_presence_of(:search_object) }
  #it 'is invalid without a search object' do
  #  build(:dataset, search_object:nil).should_not be_valid
  #end
  #it 'the search_object will accept valid JSON' do
  #  ss = build(:dataset, search_object:nil)
  #
  #  ss.search_object = ({title:'hello world'}).to_json
  #
  #  ss.should be_valid
  #end
  #it 'will not accept invalid JSON for the search_object' do
  #  ss = build(:dataset, search_object:nil)
  #
  #  ss.name = 'OK, first off: a lion, swimming in the ocean. Lions don\'t like water. If you placed it near a river or some sort of fresh water source, that make sense. But you find yourself in the ocean, 20 foot wave, I\'m assuming off the coast of South Africa, coming up against a full grown 800 pound tuna with his 20 or 30 friends, you lose that battle, you lose that battle 9 times out of 10. And guess what, you\'ve wandered into our school of tuna and we now have a taste of lion. We\'ve talked to ourselves. We\'ve communicated and said \'You know what, lion tastes good, let\'s go get some more lion\'. We\'ve developed a system to establish a beach-head and aggressively hunt you and your family and we will corner your pride, your children, your offspring. We will construct a series of breathing apparatus with kelp. We will be able to trap certain amounts of oxygen. It\'s not gonna be days at a time. An hour? Hour forty-five? No problem. That will give us enough time to figure out where you live, go back to the sea, get some more oxygen, and stalk you. You just lost at your own game. You\'re outgunned and out-manned.'
  #
  #  ss.should_not be_valid
  #end

end