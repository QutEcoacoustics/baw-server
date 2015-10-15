require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'


# https://github.com/zipmark/rspec_api_documentation
resource 'Projects' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy
  
  # prepare ids needed for paths in requests below
  let(:id) { project.id }
  let(:project_name) { project.name }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:project) }

  ################################
  # LIST
  ################################
  get '/projects' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as confirmed_user)', :ok, {
                                     expected_json_path: 'data/0/name',
                                     data_item_count: 1
                                 })
  end

  get '/projects' do
    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request_options(:get, 'LIST (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/projects' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:get, 'LIST (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:confirm)})
  end

  ################################
  # CREATE
  ################################
  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as confirmed user writer)', :created, {expected_json_path: 'data/name'})

  end

  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})

  end

  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/name'})

  end

  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})

  end

  ################################
  # SHOW
  ################################
  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/name'})

  end
  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})

  end

  ################################
  # UPDATE
  ################################
  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/name'})
  end

  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end


  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }

    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  # Filter (#filter)
  # ================

  post '/projects/filter' do
    let(:raw_post) {
      {
          'filter' => {
              'id' => {
                  'in' => [reader_permission.project.id]
              }
          },
          'projection' => {
              'include' => [:id, :name]
          }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
                                      expected_json_path: ['data/0/name', 'meta/projection/include'],
                                      data_item_count: 1,
                                      regex_match: /"site_ids"\:\[[0-9]+\]/,
                                      response_body_content: "\"site_ids\":[",
                                      invalid_content: "\"site_ids\":[{\"id\":"
                                  })
  end

  get '/projects/filter?direction=desc&filter_name=a&filter_partial_match=partial_match_text&items=35&order_by=createdAt&page=1' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'BASIC FILTER (as reader with filtering, sorting, paging)', :ok, {
                                     expected_json_path: 'meta/paging/current',
                                     data_item_count: 0,
                                     response_body_content: '/projects/filter?direction=desc\u0026filter_name=a\u0026filter_partial_match=partial_match_text\u0026items=35\u0026order_by=createdAt\u0026page=1'
                                 })
  end

end