# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id                      :integer          not null, primary key
#  allow_audio_upload      :boolean          default(FALSE)
#  allow_original_download :string
#  deleted_at              :datetime
#  description             :text
#  image_content_type      :string
#  image_file_name         :string
#  image_file_size         :bigint
#  image_updated_at        :datetime
#  license                 :text
#  name                    :string           not null
#  notes                   :text
#  urn                     :string
#  created_at              :datetime
#  updated_at              :datetime
#  creator_id              :integer          not null
#  deleter_id              :integer
#  updater_id              :integer
#
# Indexes
#
#  index_projects_on_creator_id  (creator_id)
#  index_projects_on_deleter_id  (deleter_id)
#  index_projects_on_updater_id  (updater_id)
#  projects_name_uidx            (name) UNIQUE
#
# Foreign Keys
#
#  projects_creator_id_fk  (creator_id => users.id)
#  projects_deleter_id_fk  (deleter_id => users.id)
#  projects_updater_id_fk  (updater_id => users.id)
#
describe Project do
  it 'has a valid factory' do
    expect(create(:project)).to be_valid
  end

  it { is_expected.to have_many :permissions }
  it { is_expected.to have_many :regions }

  it { is_expected.to have_many :harvests }

  it { is_expected.to have_many(:sites).through(:projects_sites) }
  it { is_expected.to have_many :projects_sites }

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it 'is invalid without a name' do
    expect(build(:project, name: nil)).not_to be_valid
  end

  it 'is invalid without a creator' do
    expect {
      create(:project, creator_id: nil)
    }.to raise_error(ActiveRecord::RecordInvalid, /must exist/)
  end

  it 'is invalid without a created_at' do
    expect(create(:project, created_at: nil)).not_to be_a_new(Project)
  end

  it 'generates html for description' do
    md = "# Header\r\n [a link](https://github.com)."
    html = "<h1 id=\"header\">Header</h1>\n<p><a href=\"https://github.com\">a link</a>.</p>\n"
    project_html = create(:project, description: md)

    expect(project_html.description).to eq(md)
    expect(project_html.description_html).to eq(html)
  end

  it 'validates license is not an empty string' do
    expect(build(:project, license: '')).not_to be_valid
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

  it_behaves_like 'cascade deletes for', :project, {
    regions: {
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
          statistics: nil
        }
      }
    },
    projects_sites: nil,
    projects_saved_searches: nil,
    permissions: nil,
    harvests: {
      harvest_items: nil
    },
    analysis_jobs: {
      analysis_jobs_scripts: nil,
      analysis_jobs_items: nil
    }
  } do
    create_entire_hierarchy
  end
end
