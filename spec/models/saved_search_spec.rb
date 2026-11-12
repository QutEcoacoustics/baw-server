# frozen_string_literal: true

# == Schema Information
#
# Table name: saved_searches
#
#  id           :integer          not null, primary key
#  deleted_at   :datetime
#  description  :text
#  name         :string           not null
#  stored_query :jsonb            not null
#  created_at   :datetime         not null
#  creator_id   :integer          not null
#  deleter_id   :integer
#
# Indexes
#
#  index_saved_searches_on_creator_id   (creator_id)
#  index_saved_searches_on_deleter_id   (deleter_id)
#  saved_searches_name_creator_id_uidx  (name,creator_id) UNIQUE
#
# Foreign Keys
#
#  saved_searches_creator_id_fk  (creator_id => users.id)
#  saved_searches_deleter_id_fk  (deleter_id => users.id)
#
describe SavedSearch do
  it 'has a valid factory' do
    expect(create(:saved_search)).to be_valid
  end

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:deleter).optional }

  it { is_expected.to validate_presence_of(:stored_query) }

  it 'encodes the stored query as jsonb' do
    expect(SavedSearch.columns_hash['stored_query'].type).to eq(:jsonb)
  end

  it 'is invalid without name specified' do
    b = build(:saved_search, name: nil)
    expect(b).not_to be_valid
  end

  it 'does not allow duplicate names for the same user (case-insensitive)' do
    user = create(:user)
    create(:saved_search, { creator: user, name: 'I love the smell of napalm in the morning.' })
    ss = build(:saved_search, { creator: user, name: 'I LOVE the smell of napalm in the morning.' })
    expect(ss).not_to be_valid
    expect(ss).not_to be_valid
    expect(ss.errors[:name].size).to eq(1)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    expect(ss).to be_valid
  end

  it 'allows duplicate names for different users (case-insensitive)' do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    ss1 = create(:saved_search, { creator: user1, name: "You talkin' to me?" })

    ss2 = build(:saved_search, { creator: user2, name: "You TALKIN' to me?" })
    expect(ss2.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss2).to be_valid

    ss3 = build(:saved_search, { creator: user3, name: "You talkin' to me?" })
    expect(ss3.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss3).to be_valid
  end

  it 'is valid without projects' do
    expect(create(:saved_search).projects.size).to eq(0)
  end

  it 'has a valid query' do
    ss = create(:saved_search)
    ss.audio_recording_conditions(ss.creator)
  end

  it 'returns the expected audio recording ids from the query' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = create(:saved_search, creator: user, stored_query: { id: { in: [audio_recording_2.id] } })

    result = ss.audio_recordings_extract(user)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.count).to eq(1)
    expect(result.first).to eq(audio_recording_2)
  end

  it 'populates the projects used in the query' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)
    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = create(:saved_search, creator: user, stored_query: { id: { in: [audio_recording_2.id] } })

    result = ss.projects_extract(user)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.count).to eq(1)
    expect(result.first).to eq(project_2)
  end

  it 'has a project if populated in many to many table' do
    project = create(:project)
    saved_search = create(:saved_search, projects: [project])

    expect(saved_search.projects.size).to eq(1)
  end

  it 'has a project if populated in many to many table manually' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = build(:saved_search, creator: user, stored_query: { id: { in: [audio_recording_2.id] } })

    result = ss.projects_extract(user)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.count).to eq(1)
    expect(result.first).to eq(project_2)

    ss.projects = result

    expect(ss.projects.size).to eq(1)

    ss.save

    expect(SavedSearch.find(ss.id).projects.size).to eq(1)
    expect(SavedSearch.find(ss.id).projects.pluck(:id)[0]).to eq(project_2.id)
  end

  it 'has a project if populated in many to many table on create' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = build(:saved_search, creator: user, stored_query: { id: { in: [audio_recording_2.id] } })

    ss.projects_populate(user)

    ss.save

    expect(SavedSearch.find(ss.id).projects.size).to eq(1)
    expect(SavedSearch.find(ss.id).projects.pluck(:id)[0]).to eq(project_2.id)
  end
end
