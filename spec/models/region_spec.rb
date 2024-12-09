# frozen_string_literal: true

# == Schema Information
#
# Table name: regions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  name        :string
#  notes       :jsonb
#  created_at  :datetime
#  updated_at  :datetime
#  creator_id  :integer
#  deleter_id  :integer
#  project_id  :integer          not null
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
describe Region, type: :model do
  it 'has a valid factory' do
    expect(create(:region)).to be_valid
  end

  it 'is invalid without a name' do
    expect(build(:region, name: nil)).not_to be_valid
  end

  it 'requires a name with at least two characters' do
    s = build(:region, name: 's')
    expect(s).not_to be_valid
    expect(s).not_to be_valid
    expect(s.errors[:name].size).to eq(1)
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:sites) }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it { is_expected.to validate_size_of(:image).less_than_or_equal_to(BawApp.attachment_size_limit) }
  it { is_expected.to validate_content_type_of(:image).allowing('image/png', 'image/jpeg') }
  it { is_expected.to validate_content_type_of(:image).rejecting('text/plain', 'text/xml') }

  it_behaves_like 'cascade deletes for', :region, {
    sites: {
      audio_recordings: {
        audio_events: {
          taggings: nil,
          comments: nil
        },
        analysis_jobs_items: :audio_event_import_files,
        bookmarks: nil,
        dataset_items: {
          progress_events: nil,
          responses: nil
        },
        harvest_item: nil,
        statistics: nil
      },
      projects_sites: nil
    }
  } do
    create_entire_hierarchy
  end
end
