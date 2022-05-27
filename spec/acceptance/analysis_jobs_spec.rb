# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def id_params
  parameter :id, 'Analysis Job id in request url', required: true
end

def body_params
  parameter :script_id, 'Analysis Job script id in request body', required: true
  parameter :saved_search_id, 'Analysis Job saved search id in request body', required: true

  parameter :name, 'Analysis Job name in request body', required: true
  parameter :annotation_name, 'Analysis Job annotation name in request body', required: false
  parameter :custom_settings, 'Analysis Job custom settings in request body', required: true
  parameter :description, 'Analysis Job description in request body', required: false
end

# https://github.com/zipmark/rspec_api_documentation
resource 'AnalysisJobs' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  let(:body_attributes) {
    FactoryBot
      .attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id)
      .except(:started_at, :overall_progress,
        :overall_progress_modified_at, :overall_count,
        :overall_duration_seconds, :overall_data_length_bytes)
      .to_json
  }

  let(:body_attributes_update) {
    FactoryBot
      .attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id)
      .slice(:name, :description)
      .to_json
  }

  post '/analysis_jobs' do
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'name' => 'job test creation',
        'custom_settings' => '#custom settings 267',
        'script_id' => 999_899,
        'saved_search_id' => 99_989,
        'format' => 'json',
        'controller' => 'analysis_jobs',
        'action' => 'create',
        'analysis_job' =>
              {
                'name' => 'job test creation',
                'custom_settings' => '#custom settings 267',
                'script_id' => 999_899,
                'saved_search_id' => 99_989
              }
      }.to_json
    }
    let!(:preparation_create) {
      project = Creation::Common.create_project(writer_user)
      script = FactoryBot.create(:script, creator: writer_user, id: 999_899)

      saved_search = FactoryBot.create(:saved_search, creator: writer_user, id: 99_989)
      saved_search.projects << project
      saved_search.save!
      saved_search
    }

    standard_request_options(:post, 'CREATE (as writer, testing projects error)', :created,
      { expected_json_path: 'data/saved_search_id' })
  end

  describe 'update special case - retrying the job' do
    def set_completed
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'completed')
      AnalysisJobsItem.update_all status: :failed
    end

    # special case - retrying the job
    put '/analysis_jobs/:id' do
      pause_all_jobs
      ignore_pending_jobs

      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_completed
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'processing' } }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (retry job, as admin)', :ok,
        { expected_json_path: 'data/saved_search_id' })
    end

    # special case - retrying the job
    put '/analysis_jobs/:id' do
      pause_all_jobs
      ignore_pending_jobs

      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_completed
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'processing' } }.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (retry job,  writer)', :ok, { expected_json_path: 'data/saved_search_id' })
    end
  end

  describe 'update special case - pausing the job' do
    def set_processing
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'processing')
      #AnalysisJobsItem.update_all status: :failed
    end

    # special case - pausing the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_processing
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'suspended' } }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (pause job, as admin)', :ok,
        { expected_json_path: 'data/saved_search_id' })
    end

    # special case - pausing the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_processing
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'suspended' } }.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (pause job,  writer)', :ok, { expected_json_path: 'data/saved_search_id' })
    end
  end

  describe 'update special case - resuming the job' do
    def set_suspended
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'suspended')
      #AnalysisJobsItem.update_all status: :failed
    end

    # special case - resuming the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_suspended
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'processing' } }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (pause job, as admin)', :ok,
        { expected_json_path: 'data/saved_search_id' })
    end

    # special case - resuming the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # HACK: insert here for correct execution time
        set_suspended
        analysis_job.id
      }
      let(:raw_post) { { analysis_job: { overall_status: 'processing' } }.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (pause job,  writer)', :ok, { expected_json_path: 'data/saved_search_id' })
    end
  end

  ################################
  # FILTER
  ################################

  post '/analysis_jobs/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        filter: {
          'saved_searches.stored_query' => {
            contains: 'blah'
          }
        },
        projection: {
          include: ['id', 'name', 'saved_search_id']
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as reader)', :ok, {
      expected_json_path: 'meta/filter/saved_searches.stored_query',
      data_item_count: 1,
      response_body_content: ['"saved_searches.stored_query":{"contains":"blah"}'],
      invalid_content: ['"saved_search":', '"script":']
    })
  end

  post '/analysis_jobs/filter' do
    let(:authentication_token) { no_access_token }
    let(:raw_post) {
      {
        filter: {
          name: {
            contains: 'name'
          }
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as no access user)', :ok, {
      response_body_content: [
        '{"meta":{"status":200,"message":"OK","filter":{"name":{"contains":"name"}},',
        '"paging":{"page":1,"items":25,"total":0,"max_page":0,'
      ],
      data_item_count: 0
    })
  end
end
