require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'AnalysisJobs' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    @admin_user = FactoryGirl.create(:admin)
    @writer_user = FactoryGirl.create(:user)
    @reader_user = FactoryGirl.create(:user)
    @other_user = FactoryGirl.create(:user)
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)

    @write_permission = FactoryGirl.create(:write_permission, creator: @admin_user, user: @writer_user)
    @read_permission = FactoryGirl.create(:read_permission, creator: @admin_user, user: @reader_user, project: @write_permission.project)

    @saved_search = @write_permission.project.saved_searches.first
    @analysis_job = @saved_search.analysis_jobs.first
    @script = @analysis_job.script
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@writer_user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@reader_user.authentication_token}\"" }
  let(:other_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:post_attributes) {}

  ################################
  # INDEX
  ################################

  get '/analysis_jobs' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok)
  end

  ################################
  # SHOW
  ################################

  get '/analysis_jobs/:id' do
    parameter :id, 'Requested analysis job id (in path/route)', required: true
    #let(:id) { @analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok)
  end

  ################################
  # NEW
  ################################

  get '/analysis_jobs/new' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  ################################
  # CREATE
  ################################

  post '/analysis_jobs' do
    let(:raw_post) { {analysis_job: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/analysis_identifier'})
  end

  ################################
  # UPDATE
  ################################

  put '/analysis_jobs/:id' do
    parameter :id, 'Requested analysis job id (in path/route)', required: true
    let(:id) { @analysis_job.id }
    let(:raw_post) { {analysis_job: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok)
  end

  patch '/analysis_jobs/:id' do
    parameter :id, 'Requested analysis job id (in path/route)', required: true
    let(:id) { @analysis_job.id }
    let(:raw_post) { {analysis_job: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok)
  end

  ################################
  # DESTROY
  ################################

  delete '/analysis_jobs/:id' do
    parameter :id, 'Requested analysis job id (in path/route)', required: true
    let(:id) { @analysis_job.id }
    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DESTROY (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  ################################
  # FILTER
  ################################

  post '/analysis_jobs/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        filter: {

        },
        projection: {
            include: %w(id name analysis_identifier)
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
                                      expected_json_path: 'meta/filter/analysis_identifier',
                                      data_item_count: 1,
                                      response_body_content: '"analysis_identifier":"something something"'
                                  })
  end

end