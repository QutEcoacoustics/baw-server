# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs' do
  include_context 'with analysis jobs context'
  ignore_pending_jobs

  before do
    create_job
  end

  it 'cannot delete a job that is still running' do
    # since the only state we can't delete from is preparing
    # and that happens in the create request,
    # it seems very unlikely that this branch will ever occur
    # but it's here for completeness
    current_job.update_column(:overall_status, :preparing)

    delete "/analysis_jobs/#{current_job.id}", **api_with_body_headers(owner_token)

    expect_error(
      :conflict,
      'Cannot be deleted while `overall_status` is `preparing`'
    )
  end

  it_behaves_like 'an archivable route', {
    route: -> { "/analysis_jobs/#{current_job.id}" },
    instance: -> { current_job },
    supports_additional_actions: false
  }
end
