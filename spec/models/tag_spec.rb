require 'spec_helper'


describe Tag do
  it 'has a valid factory' do
    t = create(:tag)

    t.should be_valid
  end

  it {should have_many(:taggings)}
  it {should have_many(:audio_events)}

  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }

  it 'should not allow nil for is_taxanomic' do
    build(:tag, is_taxanomic: nil).should_not be_valid
  end
  it 'ensures is_taxanomic can be true or false' do
    t = build(:tag)
    t.should be_valid
    t.is_taxanomic = true
    t.should be_valid
    t.is_taxanomic = false
    t.should be_valid
  end

  it 'should not allow nil for text' do
    t = build(:tag, text: nil)
    t.should_not be_valid
  end
  it 'should not allow empty string though, for text' do
    build(:tag, text: '').should_not be_valid
  end
  it 'should ensure text is unique (case-insensitive)' do
    create(:tag, text: 'Rabbit')
    t = build(:tag, text: 'rabbiT')
    t.should_not be_valid
    t.should have(1).error_on(:text)
  end

  it 'should be not valid without a type_of_tag field specified' do
    build(:tag, type_of_tag: nil).should_not be_valid
  end

  it 'should be not valid with an invalid type_of_tag field specified' do
    build(:tag, type_of_tag: :this_is_not_valid).should_not be_valid
  end

  type_of_tags = [:general, :common_name, :species_name, :looks_like, :sounds_like]

  type_of_tags.each { |tag_type|
    it "ensures type_of_tag can be set to #{tag_type}" do
      t = build(:tag)
      t.should be_valid
      t.type_of_tag = tag_type
      t.should be_valid

      type_of_tags.each { |type_of_tag|
        t.send(type_of_tag.to_s + '?').should == (type_of_tag.to_s == t.type_of_tag)
      }

    end
  }

  it 'should not allow nil for retired' do
    t = build(:tag)
    t.retired = nil
    t.should_not be_valid
  end
  it 'ensures retired can be true or false' do
    t = build(:tag)
    t.should be_valid
    t.retired = true
    t.should be_valid
    t.retired = false
    t.should be_valid
  end

  it 'ensures retired should be false by default' do
    t = Tag.new()
    t.retired.should be_false
  end

end