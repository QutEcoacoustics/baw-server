require 'rails_helper'

describe 'creation helper' do
  create_entire_hierarchy
  it 'correctly creates one of everything' do
    expect(User.count).to eq(7)

    # owner permission is defined by project creator until new permissions system is implemented
    expect(Permission.count).to eq(2)
    expect(Permission.where(level: 'owner').count).to eq(0)
    expect(Permission.where(level: 'owner', user: owner_user).count).to eq(0)

    expect(Permission.where(level: 'writer').count).to eq(1)
    expect(Permission.where(level: 'writer', user: writer_user).count).to eq(1)

    expect(Permission.where(level: 'reader').count).to eq(1)
    expect(Permission.where(level: 'reader', user: reader_user).count).to eq(1)

    expect(Project.count).to eq(1)

    expect(Site.count).to eq(1)
    expect(AudioRecording.count).to eq(1)
    expect(AudioEvent.count).to eq(1)
    expect(AudioEventComment.count).to eq(1)

    expect(SavedSearch.count).to eq(1)
    expect(AnalysisJob.count).to eq(1)
    expect(Script.count).to eq(1)

    expect(Bookmark.count).to eq(1)
    expect(Tag.count).to eq(1)

    expect(Tagging.count).to eq(1)

    expect(Site.first.projects.count).to eq(1)
    expect(Project.first.sites.count).to eq(1)

    expect(Project.first.sites.first.id).to eq(Site.first.id)
    expect(Project.first.id).to eq(Site.first.projects.first.id)

    expect(Project.first.saved_searches.count).to eq(1)
    expect(SavedSearch.first.projects.count).to eq(1)

    expect(SavedSearch.first.projects.first.id).to eq(Project.first.id)
    expect(SavedSearch.first.id).to eq(Project.first.saved_searches.first.id)
  end
end