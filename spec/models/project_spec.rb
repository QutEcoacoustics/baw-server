require 'spec_helper'

describe Project do
  it 'has a valid factory' do
    FactoryGirl.create(:project).should be_valid
  end

  it { should have_many :permissions }
  it { should have_and_belong_to_many :sites }

  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }
  it { should belong_to(:deleter).with_foreign_key(:deleter_id) }

  it 'is invalid without an name' do
    FactoryGirl.build(:project, name: nil).should_not be_valid
  end
  it 'is invalid without a creator' do
    lambda { FactoryGirl.create(:project, creator_id: nil) }.should raise_error(ActiveRecord::StatementInvalid)
  end
  it 'is invalid without a created_at' do
    FactoryGirl.create(:project, created_at: nil).should_not be_a_new(Project)
  end

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  #it { should validate_attachment_content_type(:image).
  #                allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
  #                rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }


  it 'is invalid without a urn' do
    FactoryGirl.build(:project, :urn => nil).should_not be_valid
  end

  it 'requires unique case-insensitive project names (case insensitive)' do
    p1 = FactoryGirl.create(:project, :name => 'the same name')
    p2 = FactoryGirl.build(:project, :name => 'tHE Same naMe')
    p2.should_not be_valid
    p2.should have(1).error_on(:name)
  end

  it 'requires a unique urn (case insensitive)' do
    p1 = FactoryGirl.create(:project, :urn => 'urn:organisation:project')
    p2 = FactoryGirl.build(:project, :urn => 'urn:organisation:project')
    p2.should_not be_valid
    p2.should have(1).error_on(:urn)
  end

  it 'requires a valid urn' do
    FactoryGirl.build(:project, :urn => 'not a urn').should_not be_valid
  end

end