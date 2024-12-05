# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs' do
  include_context 'with analysis jobs context'

  render_error_responses

  describe 'invalid requests' do
    let(:payload) {
      {
        analysis_job: {
          name: 'test job',
          description: 'test job **description**',
          ongoing: false,
          project_id: project.id,
          system_job: false,
          scripts: [{ script_id: script_one.id }, { script_id: script_two.id }],
          filter: {}
        }
      }
    }

    it 'cannot create a job without a name' do
      params = payload.deep_merge({ analysis_job: { name: nil } })
      post('/analysis_jobs', params:, **api_with_body_headers(owner_token))
      expect_error(:unprocessable_content, 'Record could not be saved',
        { name: ["can't be blank", 'is too short (minimum is 2 characters)'] })
    end

    it 'cannot create a system job as a non-admin' do
      params = payload.deep_merge({ analysis_job: { system_job: true } })
      post('/analysis_jobs', params:, **api_with_body_headers(owner_token))
      expect_error(:forbidden, 'You do not have sufficient permissions.')
    end

    it 'cannot create a project job for a project we do not have access to' do
      project2 = create(:project)
      params = payload.deep_merge({ analysis_job: { project_id: project2.id } })

      post('/analysis_jobs', params:, **api_with_body_headers(owner_token))
      expect_error(:forbidden, 'You do not have sufficient permissions.')
    end

    it 'checks the transition is allowed (invalid transition)' do
      create_job

      post "/analysis_jobs/#{current_job.id}/invalid", params: body, **api_with_body_headers(admin_token)

      expect_error(
        :not_found,
        'Invalid action: unknown action: `invalid`',
        {
          allowed_actions: a_collection_containing_exactly('retry', 'resume', 'suspend', 'amend')
        }
      )
    end

    it 'checks the transition is allowed (valid transition but not allowed)' do
      create_job

      post "/analysis_jobs/#{current_job.id}/complete", **api_with_body_headers(admin_token)

      expect_error(
        :not_found,
        'Invalid action: unknown action: `complete`',
        {
          allowed_actions: a_collection_containing_exactly('retry', 'resume', 'suspend', 'amend')
        }
      )
    end

    it 'does not allow amendment for a non-ongoing job' do
      create_job

      post "/analysis_jobs/#{current_job.id}/amend", **api_with_body_headers(admin_token)

      expect_error(
        :unprocessable_content,
        'The request could not be understood: Cannot amend a non-ongoing job'
      )
    end
  end
end
