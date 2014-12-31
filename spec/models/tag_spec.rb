require 'spec_helper'


describe Tag, :type => :model do
  it 'has a valid factory' do
    t = create(:tag)

    expect(t).to be_valid
  end

  it { is_expected.to have_many(:taggings) }
  it { is_expected.to have_many(:audio_events) }

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }

  it 'should not allow nil for is_taxanomic' do
    expect(build(:tag, is_taxanomic: nil)).not_to be_valid
  end
  it 'ensures is_taxanomic can be true or false' do
    t = build(:tag)
    expect(t).to be_valid

    t.is_taxanomic = true
    t.type_of_tag = :common_name
    expect(t).to be_valid
    
    t.is_taxanomic = false
    t.type_of_tag = :general
    expect(t).to be_valid
  end

  it 'should not allow nil for text' do
    t = build(:tag, text: nil)
    expect(t).not_to be_valid
  end
  it 'should not allow empty string though, for text' do
    expect(build(:tag, text: '')).not_to be_valid
  end
  it 'should ensure text is unique (case-insensitive)' do
    create(:tag, text: 'Rabbit')
    t = build(:tag, text: 'rabbiT')
    expect(t).not_to be_valid
    expect(t.valid?).to be_falsey
    expect(t.errors[:text].size).to eq(1)
  end

  it 'should be not valid without a type_of_tag field specified' do
    expect(build(:tag, type_of_tag: nil)).not_to be_valid
  end

  it 'should be not valid with an invalid type_of_tag field specified' do
    expect(build(:tag, type_of_tag: :this_is_not_valid)).not_to be_valid
  end

  type_of_tags = [:general, :common_name, :species_name, :looks_like, :sounds_like]

  type_of_tags.each { |tag_type|
    expected_is_taxanomic_value = tag_type == :common_name || tag_type == :species_name
    it "ensures type_of_tag can be set to #{tag_type}" do
      t = build(:tag)
      expect(t).to be_valid
      t.type_of_tag = tag_type
      t.is_taxanomic = expected_is_taxanomic_value
      expect(t).to be_valid

      type_of_tags.each { |type_of_tag|
        expect(t.send(type_of_tag.to_s + '?')).to eq(type_of_tag.to_s == t.type_of_tag)
      }
    end

    it "ensures is_taxanomic is set to #{expected_is_taxanomic_value} for #{tag_type}" do
      t = build(:tag)
      expect(t).to be_valid

      t.type_of_tag = tag_type

      t.is_taxanomic = !expected_is_taxanomic_value
      expect(t).not_to be_valid

      t.is_taxanomic = expected_is_taxanomic_value
      expect(t).to be_valid
    end
  }

  it 'should not allow nil for retired' do
    t = build(:tag)
    t.retired = nil
    expect(t).not_to be_valid
  end
  it 'ensures retired can be true or false' do
    t = build(:tag)
    expect(t).to be_valid
    t.retired = true
    expect(t).to be_valid
    t.retired = false
    expect(t).to be_valid
  end

  it 'ensures retired should be false by default' do
    t = Tag.new
    expect(t.retired).to be_falsey
  end

end