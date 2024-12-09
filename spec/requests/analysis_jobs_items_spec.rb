# frozen_string_literal: true

describe 'AnalysisJobsItems' do
  create_entire_hierarchy

  # these specs are intentionally light weight because the batch communicator
  # specs tests workflow and status updates in more detail

  describe 'remote queue webhook status updates' do
    it 'can update status from :queued to :working' do
      analysis_jobs_item.update_column(:status, AnalysisJobsItem::STATUS_QUEUED)

      put "/analysis_jobs/#{analysis_job.id}/items/#{analysis_jobs_item.id}/#{AnalysisJobsItem::STATUS_WORKING}",
        **api_with_body_headers(harvester_token)

      expect_no_content
      expect(analysis_jobs_item.reload.status).to eq(AnalysisJobsItem::STATUS_WORKING)
    end

    it 'can update status from :working to :working (mark for transition to :finish)' do
      analysis_jobs_item.update_column(:status, AnalysisJobsItem::STATUS_WORKING)

      put "/analysis_jobs/#{analysis_job.id}/items/#{analysis_jobs_item.id}/#{AnalysisJobsItem::TRANSITION_FINISH}",
        **api_with_body_headers(harvester_token)

      expect_no_content
      # status hasn't changed - a remote job has to process the transition
      expect(analysis_jobs_item.reload.status).to eq(AnalysisJobsItem::STATUS_WORKING)

      # but the item has been marked to transition to :finish
      expect(analysis_jobs_item.reload.transition).to eq(AnalysisJobsItem::TRANSITION_FINISH)
    end

    it 'gracefully handles multiple invocations of the webhook' do
      url = "/analysis_jobs/#{analysis_job.id}/items/#{analysis_jobs_item.id}/#{AnalysisJobsItem::TRANSITION_FINISH}"
      analysis_jobs_item.update_column(:status, AnalysisJobsItem::STATUS_WORKING)

      put url, **api_with_body_headers(harvester_token)

      expect_no_content

      put url, **api_with_body_headers(harvester_token)

      expect_no_content

      expect(analysis_jobs_item.reload.status).to eq(AnalysisJobsItem::STATUS_WORKING)
    end
  end
end
