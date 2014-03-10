require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Datasets' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:id) { @write_permission.project.datasets[0].id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:dataset) }


  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
  end

  ################################
  # LIST
  ################################
  get '/projects/:project_id/datasets' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('LIST (as writer)', 200, '0/number_of_tags', true)
  end

  get '/projects/:project_id/datasets' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('LIST (as reader)', 200, '0/number_of_tags', true)
  end

  get '/projects/:project_id/datasets' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('LIST (with invalid token)', 401, nil, true)
  end


  ################################
  # CREATE
  ################################
  post '/projects/:project_id/datasets' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    standard_request('CREATE (as writer)', 201, 'number_of_tags', true)
  end

  post '/projects/:project_id/datasets' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    standard_request('CREATE (as reader)', 403, nil, true)

  end

  post '/projects/:project_id/datasets' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    standard_request('CREATE (with invalid token)', 401, nil, true)

  end

  ################################
  # SHOW
  ################################
  get '/projects/:project_id/datasets/:id' do

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    # Comparing json does not work here as newlines \n in text fields are translated into arrays
    #puts @permission.site.to_json
    #puts ActiveSupport::JSON.decode(@permission.site)
    #puts JSON.parse(response_body)
    #puts ActiveSupport::JSON.decode(response_body)
    #response_json = JSON.parse(response_body).to_s
    #response_body.should have_json_path('name')
    standard_request('SHOW (as writer)', 200, 'number_of_tags', true)
  end

  get '/projects/:project_id/datasets/:id' do
    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader)', 200, 'number_of_tags', true)
  end

  get '/projects/:project_id/datasets/:id' do
    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('SHOW (with invalid token)', 401, nil, true)
  end

  ################################
  # UPDATE
  ################################
  put '/projects/:project_id/datasets/:id' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    # Comparing json does not work here as newlines \n in text fields are translated into arrays
    #puts @permission.site.to_json
    #puts ActiveSupport::JSON.decode(@permission.site)
    #puts JSON.parse(response_body)
    #puts ActiveSupport::JSON.decode(response_body)
    #response_json = JSON.parse(response_body).to_s
    #response_body.should have_json_path('name')
    standard_request('UPDATE (as writer)', 204, nil, true)
  end

  put '/projects/:project_id/datasets/:id' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    #puts "Existing datasets: #{Dataset.all.inspect}"

    standard_request('UPDATE (as reader)', 403, nil, true)
  end

  put '/projects/:project_id/datasets/:id' do
    parameter :name, 'Data set name', scope: :dataset, required: true
    parameter :name, 'Description of data set', scope: :dataset
    parameter :start_time, 'Earliest time of day (inclusive - interval start)', scope: :dataset
    parameter :end_time, 'Latest time of day  (inclusive - interval end)', scope: :dataset
    parameter :start_date, 'Earliest date (inclusive - interval start)', scope: :dataset
    parameter :end_date, 'Latest date (inclusive - interval end)', scope: :dataset
    parameter :filters, 'Filters', scope: :dataset
    parameter :tag_text_filters, 'Array of partial tag text to filter results', scope: :dataset
    parameter :number_of_samples, 'Number of random 1 minute samples', scope: :dataset
    parameter :number_of_tags, 'Minimum number of tags required', scope: :dataset
    parameter :types_of_tags, 'Types of tags', scope: :dataset

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested dataset ID (in path/route)', required: true

    let(:raw_post) { {'dataset' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('UPDATE (with invalid token)', 401, nil, true)
  end
end