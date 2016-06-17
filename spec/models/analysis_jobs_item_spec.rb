require 'rails_helper'
require 'helpers/resque_helper'

describe AnalysisJobsItem, type: :model do
  let!(:analysis_jobs_item) { create(:analysis_jobs_item) }

  it 'has a valid factory' do
    expect(create(:analysis_jobs_item)).to be_valid
  end

  it 'cannot be created when status is not new' do
    expect {
      create(:analysis_jobs_item, status: nil)
    }.to raise_error
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

  it {
    is_expected.to enumerize(:status)
                       .in(*AnalysisJobsItem::AVAILABLE_ITEM_STATUS_SYMBOLS)
                       .with_default(:new)
  }

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

  describe 'analysis_jobs_item state transitions' do
    [
        # old, new, []shouldPass|shouldPassAndUpdateField]
        [:new, :new, true],
        [:new, :queued, :queued_at],
        [:new, :working, false],
        [:new, :successful, false],
        [:new, :failed, false],
        [:new, :timed_out, false],
        [:new, :cancelled, :completed_at],
        [:new, nil, false],
        [:queued, :new, false],
        [:queued, :queued, true],
        [:queued, :working, :work_started_at],
        [:queued, :successful, false],
        [:queued, :failed, false],
        [:queued, :timed_out, false],
        [:queued, :cancelled, :completed_at],
        [:queued, nil, false],
        [:working, :new, false],
        [:working, :queued, false],
        [:working, :working, true],
        [:working, :successful, :completed_at],
        [:working, :failed, :completed_at],
        [:working, :timed_out, :completed_at],
        [:working, :cancelled, :completed_at],
        [:working, nil, false],
        [:successful, :new, false],
        [:successful, :queued, false],
        [:successful, :working, false],
        [:successful, :successful, true],
        [:successful, :failed, false],
        [:successful, :timed_out, false],
        [:successful, :cancelled, false],
        [:successful, nil, false],
        [:failed, :new, false],
        [:failed, :queued, false],
        [:failed, :working, false],
        [:failed, :successful, false],
        [:failed, :failed, true],
        [:failed, :timed_out, false],
        [:failed, :cancelled, false],
        [:failed, nil, false],
        [:timed_out, :new, false],
        [:timed_out, :queued, false],
        [:timed_out, :working, false],
        [:timed_out, :successful, false],
        [:timed_out, :failed, false],
        [:timed_out, :timed_out, true],
        [:timed_out, :cancelled, false],
        [:timed_out, nil, false],
        [:cancelled, :new, false],
        [:cancelled, :queued, false],
        [:cancelled, :working, false],
        [:cancelled, :successful, false],
        [:cancelled, :failed, false],
        [:cancelled, :timed_out, false],
        [:cancelled, :cancelled, true],
        [:cancelled, nil, false],
        [nil, :new, false],
        [nil, :queued, false],
        [nil, :working, false],
        [nil, :successful, false],
        [nil, :failed, false],
        [nil, :timed_out, false],
        [nil, :cancelled, false],
        # if all the other combinations hold true this case will never happen anyway.
        # note: nil is a valid value for system queries, but we should never be able to
        # transition the model to nil (other cases).
        [nil, nil, true]
    ].each do |test_case|

      it "tests state transition #{ test_case[0].to_s }→#{ test_case[1].to_s }" do

        analysis_jobs_item.write_attribute(:status, test_case[0])

        date_field = test_case[2]
        if date_field
          if date_field.is_a? Symbol
            first_date = analysis_jobs_item[date_field]
          end

          analysis_jobs_item.status = test_case[1]

          expect(analysis_jobs_item.status == test_case[1]).to be true
          expect(analysis_jobs_item[date_field]).to_not eq(first_date) if date_field.is_a? Symbol
        else
          expect {
            analysis_jobs_item.status = test_case[1]
          }.to raise_error

        end
      end
    end

  end

  describe 'security for results is resolved via audio recordings' do
    # create two separate hierarchies
    create_entire_hierarchy

    let!(:second_project) {
      Creation::Common.create_project(other_user)
    }

    # The second analysis jobs item allows us to test for different permission combinations
    # In particular we want to ensure that if someone has access to a project, then they have
    # access to the results
    let!(:second_analysis_jobs_item) {
      project = second_project
      permission = FactoryGirl.create(:read_permission, creator: owner_user, user: other_user, project: project)
      site = Creation::Common.create_site(other_user, project)
      audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
      saved_search.projects << project

      Creation::Common.create_analysis_job_item(analysis_job, audio_recording)
    }

    it 'ensures users with access to all projects get all results' do
      # give the original user permissions to access the second project
      permission = FactoryGirl.create(:read_permission, creator: owner_user, user: reader_user, project: second_project)

      query = Access::Query.analysis_jobs_items(analysis_job, reader_user)

      rows = query.all

      # should have access to both projects
      expect(rows.count).to be 2
      expect(rows[0].id).to be analysis_jobs_item.id
      expect(rows[1].id).to be second_analysis_jobs_item.id
    end

    it 'ensures users with access to one project only get some recordings when new projects added' do
      query = Access::Query.analysis_jobs_items(analysis_job, reader_user)

      rows = query.all

      # should only have access to audio recording from first project
      # the user does not have access to both projects
      expect(rows.count).to be 1
      expect(rows[0].id).to be analysis_jobs_item.id
    end

    it 'ensures users with access to one projects get only some recordings' do
      query = Access::Query.analysis_jobs_items(analysis_job, other_user)

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
        project = Creation::Common.create_project(other_user)
        permission = FactoryGirl.create(:read_permission, creator: owner_user, user: other_user, project: project)
        site = Creation::Common.create_site(other_user, project)
        audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
        audio_recording
      }

      it 'only returns recordings the user has access too' do
        user = other_user

        # augment the system with query with permissions
        query = Access::Query.analysis_jobs_items(nil, user, true)

        rows = query.all

        expect(rows.count).to be 1
        expect(rows[0].audio_recording_id).to be second_recording.id
      end
    end
  end
end