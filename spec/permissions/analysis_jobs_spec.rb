# frozen_string_literal: true

describe 'Analysis Job permissions (for project jobs)' do
  create_entire_hierarchy

  # we have some complex permissions around system jobs
  # so we want to make a job that is completely outside the hierarchy
  # just to make sure extra things are not returned
  before do
    create(:analysis_job)
  end

  let!(:other_system_job) { create(:analysis_job, system_job: true, project_id: nil) }

  after do
    clear_pending_jobs
  end

  given_the_route '/analysis_jobs' do
    {
      id: analysis_job.id
    }
  end

  for_lists_expects do |user, _action|
    case user
    when :admin
      AnalysisJob.all
    when :owner, :reader, :writer
      [analysis_job, other_system_job]
    else
      [other_system_job]
    end
  end

  send_create_body do
    [
      {
        analysis_job: {
          name: 'test job',
          description: 'test job **description**',
          ongoing: true,
          project_id: project.id,
          system_job: false,
          scripts: [{ script_id: script.id }],
          filter: {}
        }
      }, :json
    ]
  end

  send_update_body do
    [{ analysis_job: { name: 'new_name' } }, :json]
  end

  actions = Set[
    { action: :retry, path: '{id}/retry', verb: :put, expect: :nothing },
    { action: :suspend, path: '{id}/suspend', verb: :put, expect: :nothing },
    { action: :resume, path: '{id}/resume', verb: :put, expect: :nothing },
    { action: :amend, path: '{id}/amend', verb: :put, expect: :nothing },
  ]

  before_request do |_user, action|
    # change state based on action
    case action
    when :suspend
      analysis_job.update_column(:overall_status, :processing)
    when :resume
      analysis_job.update_column(:overall_status, :suspended)
    when :amend, :destroy, :retry
      # can only delete an analysis job if it is suspended or completed
      analysis_job.update_column(:overall_status, :completed)
      analysis_job.ongoing = true
      analysis_job.save!
      analysis_jobs_item.result_failed!
    end
  end

  the_user :admin, can_do: everything + actions

  # Analysis jobs are tied to the user that created them.
  # In this case the writer user made the job. They can do most things
  the_users :writer, can_do: everything + actions, and_cannot_do: nothing

  # the owner can read/create any job as long as they have access to a project included in the job,
  # but can't change ones they don't own
  the_users :owner, can_do: reading + creation, and_cannot_do: mutation + actions

  # the reader can read any job as long as they have access to a project included in the job,
  # but can't change ones they don't own or create new ones
  the_users :reader, can_do: reading, and_cannot_do: mutation + actions + creation

  # No access doesn't have access to any audio, so can't create a job and
  # can't read current job
  the_user :no_access, can_do: listing, and_cannot_do: not_listing + actions

  the_user :harvester, can_do: nothing, and_cannot_do: everything + actions

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing + actions, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything + actions, fails_with: :unauthorized
end

describe 'Analysis Job permissions (for system jobs)' do
  create_entire_hierarchy

  before do
    analysis_job.project = nil
    analysis_job.system_job = true
    analysis_job.creator = User.admin_user
    analysis_job.save!
  end

  after do
    clear_pending_jobs
  end

  given_the_route '/analysis_jobs' do
    {
      id: analysis_job.id
    }
  end

  for_lists_expects do |user, _action|
    case user
    when :admin, :owner, :reader, :writer, :no_access, :anonymous
      AnalysisJob.all
    else
      []
    end
  end

  send_create_body do
    [
      {
        analysis_job: {
          name: 'test job',
          description: 'test job **description**',
          ongoing: true,
          project_id: nil,
          system_job: true,
          scripts: [{ script_id: script.id }],
          filter: {}
        }
      }, :json
    ]
  end

  send_update_body do
    [{ analysis_job: { name: 'new_name' } }, :json]
  end

  actions = Set[
    { action: :retry, path: '{id}/retry', verb: :put, expect: :nothing },
    { action: :suspend, path: '{id}/suspend', verb: :put, expect: :nothing },
    { action: :resume, path: '{id}/resume', verb: :put, expect: :nothing },
    { action: :amend, path: '{id}/amend', verb: :put, expect: :nothing },
  ]

  before_request do |_user, action|
    # change state based on action
    case action
    when :suspend
      analysis_job.update_column(:overall_status, :processing)
    when :resume
      analysis_job.update_column(:overall_status, :suspended)
    when :amend, :destroy, :retry
      # can only delete an analysis job if it is suspended or completed
      analysis_job.update_column(:overall_status, :completed)
      analysis_job.ongoing = true
      analysis_job.save!
      analysis_jobs_item.result_failed!
    end
  end

  the_user :admin, can_do: everything + actions

  # Analysis jobs are tied to the user that created them.
  # In this case the admin user made the job.
  # Other users can access the results though
  the_users :writer, :owner, :reader, :no_access,
    can_do: reading, and_cannot_do: mutation + actions + creation

  the_user :harvester, can_do: nothing, and_cannot_do: everything + actions

  the_user :anonymous, can_do: reading, and_cannot_do: mutation + actions + creation, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything + actions, fails_with: :unauthorized
end
