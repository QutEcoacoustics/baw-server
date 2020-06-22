# frozen_string_literal: true

require 'rails_helper'

describe Project, type: :model do
  it 'has a valid factory' do
    expect(FactoryBot.create(:project)).to be_valid
  end

  it { is_expected.to have_many :permissions }
  it { is_expected.to have_and_belong_to_many :sites }

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id).optional }

  it 'is invalid without a name' do
    expect(FactoryBot.build(:project, name: nil)).not_to be_valid
  end
  it 'is invalid without a creator' do
    expect {
      FactoryBot.create(:project, creator_id: nil)
    }.to raise_error(ActiveRecord::RecordInvalid, /must exist/)
  end
  it 'is invalid without a created_at' do
    expect(FactoryBot.create(:project, created_at: nil)).not_to be_a_new(Project)
  end

  it 'generates html for description' do
    md = "# Header\r\n [a link](https://github.com)."
    html = "<h1>Header</h1>\n<p><a href=\"https://github.com\">a link</a>.</p>\n"
    project_html = FactoryBot.create(:project, description: md)

    expect(project_html.description).to eq(md)
    expect(project_html.description_html).to eq(html)
  end

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  #it { should validate_attachment_content_type(:image).
  #                allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
  #                rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }

  #it 'is invalid without a urn' do
  #  FactoryBot.build(:project, :urn => nil).should_not be_valid
  #end
  #it 'requires unique case-insensitive project names (case insensitive)' do
  #  p1 = FactoryBot.create(:project, :name => 'the same name')
  #  p2 = FactoryBot.build(:project, :name => 'tHE Same naMe')
  #  p2.should_not be_valid
  #  p2.should have(1).error_on(:name)
  #end
  #it 'requires a unique urn (case insensitive)' do
  #  p1 = FactoryBot.create(:project, :urn => 'urn:organisation:project')
  #  p2 = FactoryBot.build(:project, :urn => 'urn:organisation:project')
  #  p2.should_not be_valid
  #  p2.should have(1).error_on(:urn)
  #end
  #it 'requires a valid urn' do
  #  FactoryBot.build(:project, :urn => 'not a urn').should_not be_valid
  #end
end
