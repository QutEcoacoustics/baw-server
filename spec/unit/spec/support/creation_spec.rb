# frozen_string_literal: true

describe 'creation helper' do
  create_entire_hierarchy
  create_study_hierarchy

  it 'correctly creates one of everything' do
    expect(User.count).to eq(6)
    expect(User.where(user_name: 'Admin').count).to eq(1)
    expect(User.where(user_name: 'Harvester').count).to eq(1)
    expect(User.where(user_name: 'owner user').count).to eq(1)
    expect(User.where(user_name: 'writer').count).to eq(1)
    expect(User.where(user_name: 'reader').count).to eq(1)
    expect(User.where(user_name: 'no_access').count).to eq(1)

    expect(Permission.count).to eq(3)

    expect(Permission.where(level: 'owner', project:, user: owner_user).count).to eq(1)
    expect(Permission.where(level: 'writer', project:, user: writer_user).count).to eq(1)
    expect(Permission.where(level: 'reader', project:, user: reader_user).count).to eq(1)

    expect(Project.count).to eq(1)

    expect(Site.count).to eq(1)
    expect(AudioRecording.count).to eq(1)
    expect(Statistics::AudioRecordingStatistics.count).to eq(1)
    expect(AudioEvent.count).to eq(1)
    expect(AudioEventComment.count).to eq(1)

    expect(SavedSearch.count).to eq(1)
    expect(AnalysisJob.count).to eq(1)
    expect(Script.count(:all)).to eq(1)

    expect(Bookmark.count).to eq(1)
    expect(Tag.count).to eq(1)

    expect(Tagging.count).to eq(1)

    expect(Site.first.projects.count).to eq(1)
    expect(Project.first.sites.count).to eq(1)

    expect(Project.first.sites.first.name).to eq(Site.first.name)
    expect(Project.first.name).to eq(Site.first.projects.first.name)

    expect(Project.first.saved_searches.count).to eq(1)
    expect(SavedSearch.first.projects.count).to eq(1)

    expect(SavedSearch.first.projects.first.id).to eq(Project.first.id)
    expect(SavedSearch.first.id).to eq(Project.first.saved_searches.first.id)

    #expect(AnalysisJob.first.saved_search.id).to eq(SavedSearch.first.id)
    #expect(AnalysisJob.first.id).to eq(SavedSearch.first.analysis_jobs.first.id)
    expect(AnalysisJob.first.scripts.count('*')).to eq(1)
    expect(AnalysisJob.first.scripts.map(&:id)).to eq(Script.all.map(&:id))

    expect(AnalysisJobsItem.first.analysis_job.id).to eq(AnalysisJob.first.id)
    expect(AnalysisJobsItem.first.id).to eq(AnalysisJob.first.analysis_jobs_items.first.id)
    expect(AnalysisJobsItem.first.audio_recording.id).to eq(AudioRecording.first.id)
    expect(AnalysisJobsItem.first.id).to eq(AudioRecording.first.analysis_jobs_items.first.id)

    expect(Dataset.count).to eq(2)
    expect(DatasetItem.count).to eq(2)
    # AT 2020: This is untrue, especially if there has been any churn on the id sequence
    # Disabling but leaving for documentation since I'm not sure what effect this will have.
    #expect(Dataset.all[1].id).to eq(DatasetItem.first.dataset_id)

    expect(Study.count).to eq(2)
    expect(Question.count).to eq(2)
    expect(Response.count).to eq(2)
  end
end
