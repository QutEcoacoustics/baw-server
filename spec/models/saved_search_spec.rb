require 'spec_helper'

describe SavedSearch, type: :model do

  it 'has a valid factory' do
    expect(create(:saved_search)).to be_valid
  end

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { is_expected.to validate_presence_of(:stored_query) }
  it { is_expected.to serialize(:stored_query) }

  it 'is invalid without name specified' do
    b = build(:saved_search, name: nil)
    expect(b).not_to be_valid
  end

  it 'should not allow duplicate names for the same user (case-insensitive)' do
    user = create(:user)
    create(:saved_search, {creator: user, name: 'I love the smell of napalm in the morning.'})
    ss = build(:saved_search, {creator: user, name: 'I LOVE the smell of napalm in the morning.'})
    expect(ss).not_to be_valid
    expect(ss.valid?).to be_falsey
    expect(ss.errors[:name].size).to eq(1)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    expect(ss).to be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    ss1 = create(:saved_search, {creator: user1, name: "You talkin' to me?"})

    ss2 = build(:saved_search, {creator: user2, name: "You TALKIN' to me?"})
    expect(ss2.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss2).to be_valid

    ss3 = build(:saved_search, {creator: user3, name: "You talkin' to me?"})
    expect(ss3.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss3).to be_valid
  end

  it 'is valid without projects' do
    expect(create(:saved_search).projects.size).to eq(0)
  end

  it 'is valid without analysis_jobs' do
    expect(create(:saved_search).analysis_jobs.size).to eq(0)
  end

  it 'should have a valid query' do
    ss = create(:saved_search)
    ss.audio_recording_conditions(ss.creator)
  end

  it 'should return the expected audio recording ids from the query' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = create(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})

    result = ss.audio_recordings_extract(user)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.count).to eq(1)
    expect(result.first).to eq(audio_recording_2)
  end

  it 'should populate the projects used in the query' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)
    audio_recording_1 = create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = create(:saved_search, creator: user, stored_query:  {id: {in: [audio_recording_2.id]}})

    result = ss.projects_extract(user)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.count).to eq(1)
    expect(result.first).to eq(project_2)
  end

  it 'should have a project if populated in many to many table' do
    project = create(:project)
    saved_search = create(:saved_search, projects: [project])

    expect(saved_search.projects.size).to eq(1)
  end

  it 'should have a project if populated in many to many table manually' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = build(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})

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

  it 'should have a project if populated in many to many table on create' do
    project_1 = create(:project)
    user = project_1.creator
    site_1 = create(:site, projects: [project_1], creator: user)

    create(:audio_recording, site: site_1, creator: user, uploader: user)

    project_2 = create(:project, creator: user)
    site_2 = create(:site, projects: [project_2], creator: user)
    audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

    ss = build(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})

    ss.projects_populate(user)

    expect(SavedSearch.find(ss.id).projects.size).to eq(1)
    expect(SavedSearch.find(ss.id).projects.pluck(:id)[0]).to eq(project_2.id)
  end

  it 'should have an analysis_job if an analysis job uses the saved search' do
    saved_search = create(:saved_search)
    analysis_job = create(:analysis_job, saved_search: saved_search)

    expect(saved_search.analysis_jobs.size).to eq(1)
  end

end