require 'rails_helper'
require 'helpers/resque_helper'
require 'aasm/rspec'

describe AnalysisJobsItem, type: :model do
  let!(:analysis_jobs_item) { create(:analysis_jobs_item) }

  it 'has a valid factory' do
    expect(create(:analysis_jobs_item)).to be_valid
  end

  it 'cannot be created when status is not new' do
    expect {
      create(:analysis_jobs_item, status: nil)
    }.to raise_error(RuntimeError, /AnalysisJobItem#status: Invalid state transition/)
  end

  it 'created_at should be set by rails' do
    item = create(:analysis_jobs_item)
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true

    item.reload

    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
  end


  it { is_expected.to belong_to(:analysis_job) }
  it { is_expected.to belong_to(:audio_recording) }


  # it { should validate_presence_of(:status) }
  #
  # it { should validate_length_of(:status).is_at_least(2).is_at_most(255) }

  it { should validate_uniqueness_of(:queue_id) }


  it 'does not allow dates greater than now for created_at' do
    analysis_jobs_item.created_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for queued_at' do
    analysis_jobs_item.queued_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for work_started_at' do
    analysis_jobs_item.work_started_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for completed_at' do
    analysis_jobs_item.completed_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  describe 'state machine' do
    let(:analysis_jobs_item) {
      create(:analysis_jobs_item)
    }

    it 'defines the queue event' do
      expect(analysis_jobs_item).to transition_from(:new).to(:queued).on_event(:queue)
    end

    it 'defines the work event' do
      expect(analysis_jobs_item).to transition_from(:queued).to(:working).on_event(:work)
    end

    it 'defines the succeed event' do
      expect(analysis_jobs_item).to transition_from(:working).to(:successful).on_event(:succeed)
      expect(analysis_jobs_item).to transition_from(:cancelling).to(:successful).on_event(:succeed)
      expect(analysis_jobs_item).to transition_from(:cancelled).to(:successful).on_event(:succeed)
    end

    it 'defines the fail event' do
      expect(analysis_jobs_item).to transition_from(:working).to(:failed).on_event(:fail)
      expect(analysis_jobs_item).to transition_from(:cancelling).to(:failed).on_event(:fail)
      expect(analysis_jobs_item).to transition_from(:cancelled).to(:failed).on_event(:fail)
    end

    it 'defines the time_out event' do
      expect(analysis_jobs_item).to transition_from(:working).to(:timed_out).on_event(:time_out)
      expect(analysis_jobs_item).to transition_from(:cancelling).to(:timed_out).on_event(:time_out)
      expect(analysis_jobs_item).to transition_from(:cancelled).to(:timed_out).on_event(:time_out)
    end

    it 'defines the cancel event' do
      expect(analysis_jobs_item).to transition_from(:queued).to(:cancelling).on_event(:cancel)
    end

    it 'defines the confirm_cancel event' do
      expect(analysis_jobs_item).to transition_from(:cancelling).to(:cancelled).on_event(:confirm_cancel)
    end

    it 'defines the retry event' do
      expect(analysis_jobs_item).to transition_from(:failed).to(:queued).on_event(:retry)
      expect(analysis_jobs_item).to transition_from(:timed_out).to(:queued).on_event(:retry)
      expect(analysis_jobs_item).to transition_from(:cancelling).to(:queued).on_event(:retry)
      expect(analysis_jobs_item).to transition_from(:cancelled).to(:queued).on_event(:retry)
    end

  end

  describe 'security for results is resolved via audio recordings' do
    # create two separate hierarchies
    create_entire_hierarchy

    let!(:second_project) {
      Creation::Common.create_project(no_access_user)
    }

    # The second analysis jobs item allows us to test for different permission combinations
    # In particular we want to ensure that if someone has access to a project, then they have
    # access to the results
    let!(:second_analysis_jobs_item) {
      project = second_project
      site = Creation::Common.create_site(no_access_user, project)
      audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
      saved_search.projects << project

      Creation::Common.create_analysis_job_item(analysis_job, audio_recording)
    }

    it 'ensures users with access to all projects get all results' do
      # give the original user permissions to access the second project
      permission = FactoryGirl.create(:read_permission, creator: owner_user, user: reader_user, project: second_project)

      query = Access::ByPermission.analysis_jobs_items(analysis_job, reader_user)

      rows = query.all

      # should have access to both projects
      expect(rows.count).to be 2
      expect(rows[0].id).to be analysis_jobs_item.id
      expect(rows[1].id).to be second_analysis_jobs_item.id
    end

    it 'ensures users with access to one project only get some recordings when new projects added' do
      query = Access::ByPermission.analysis_jobs_items(analysis_job, reader_user)

      rows = query.all

      # should only have access to audio recording from first project
      # the user does not have access to both projects
      expect(rows.count).to be 1
      expect(rows[0].id).to be analysis_jobs_item.id
    end

    it 'ensures users with access to one projects get only some recordings' do
      query = Access::ByPermission.analysis_jobs_items(analysis_job, no_access_user)

      rows = query.all

      # should only have access to the recording from the second project, the user doesn't have access to the original
      # project.
      expect(rows.count).to be 1
      expect(rows[0].id).to be second_analysis_jobs_item.id
    end
  end

  describe 'system query' do
    it 'returns the same number of audio_recordings as exist in the db' do
      ar = FactoryGirl.create(:audio_recording)
      ar1 = FactoryGirl.create(:audio_recording)

      ar_count = AnalysisJobsItem.system_query.count
      expect(ar_count).to be 3
    end

    it 'does not return deleted audio_recordings' do
      ar = FactoryGirl.create(:audio_recording)

      ar_count_unscoped = AudioRecording.unscoped.count
      expect(ar_count_unscoped).to be 2

      AudioRecording.delete(ar.id)

      ar_count_unscoped = AudioRecording.unscoped.count
      expect(ar_count_unscoped).to be 2

      ar_count = AudioRecording.count
      expect(ar_count).to be 1

      ar_count = AnalysisJobsItem.system_query.count
      expect(ar_count).to be 1
    end

    it 'fakes the audio_recording_id field' do
      ar = FactoryGirl.create(:audio_recording)
      ar1 = FactoryGirl.create(:audio_recording)

      results = AnalysisJobsItem.system_query.all

      expect(results.count('*')).to be 3

      valid_ids = [analysis_jobs_item.audio_recording_id, ar.id, ar1.id]
      results.each { |item|
        expect(item.audio_recording_id).not_to be_nil
        expect(valid_ids.include?(item.audio_recording_id)).to be_truthy
      }
    end

    it 'dummies the analysis_job_id field' do
      results = AnalysisJobsItem.system_query.all.to_a

      expect(results.size).to be 1

      expect(results[0].analysis_job_id).to eq('system')
    end

    describe 'security for system query' do
      # create two separate hierarchies
      create_entire_hierarchy

      # the values from the second will be our case
      let!(:second_recording) {
        project = Creation::Common.create_project(no_access_user)
        site = Creation::Common.create_site(no_access_user, project)
        audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
        audio_recording
      }

      it 'only returns recordings the user has access too' do
        user = no_access_user

        # augment the system with query with permissions
        query = Access::ByPermission.analysis_jobs_items(nil, user, true)

        rows = query.all

        expect(rows.count).to be 1
        expect(rows[0].audio_recording_id).to be second_recording.id
      end
    end
  end

  context 'job items' do

    it 'extracts the correct payloads' do
      project_1 = create(:project)
      user = project_1.creator
      site_1 = create(:site, projects: [project_1], creator: user)

      create(:audio_recording, site: site_1, creator: user, uploader: user)

      project_2 = create(:project, creator: user)
      site_2 = create(:site, projects: [project_2], creator: user)
      audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

      ss = create(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})
      s = create(:script, creator: user, verified: true)

      aj = create(:analysis_job, creator: user, script: s, saved_search: ss)

      payload = AnalysisJobsItem.create_action_payload(aj, audio_recording_2)

      # ensure result is as expected
      expect(payload.is_a?(Hash)).to be_truthy
      expect(payload[:command_format]).to eq(aj.script.executable_command)
      expect(payload[:uuid]).to eq(audio_recording_2.uuid)
      expect(payload[:id]).to eq(audio_recording_2.id)
      expect(payload[:datetime_with_offset]).to eq(audio_recording_2.recorded_date.iso8601(3))
      expect(payload[:job_id]).to eq(aj.id)
    end

  end
end