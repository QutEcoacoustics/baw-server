require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def id_params
  parameter :id, 'Project id in request url', required: true
end

def body_params
  parameter :name, 'Name of project', scope: :project, :required => true
  parameter :description, 'Description of project', scope: :project
  parameter :notes, 'Notes of project', scope: :project
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Projects' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:project, name: 'New Project name') }

  ################################
  # INDEX
  ################################

  get '/projects' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  get '/projects' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  get '/projects' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  get '/projects' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'INDEX (as no access user)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  get '/projects' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/projects' do
    standard_request_options(:get, 'INDEX (as anonymous user)', :ok, {remove_auth: true, response_body_content: '200', data_item_count: 0})
  end

  get '/projects' do
    prepare_project_anon
    standard_request_options(:get, 'INDEX (as anonymous user allowed read)', :ok,
                             {remove_auth: true, expected_json_path: 'data/0/name', data_item_count: 1, response_body_content: ['200', 'Anon Project']})
  end

  get '/projects' do
    prepare_project_logged_in
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'INDEX (as no access user allowed read)', :ok,
                             {expected_json_path: 'data/0/name', data_item_count: 1, response_body_content: ['200', 'Logged In Project']})
  end

  get '/projects' do
    prepare_project_logged_in
    standard_request_options(:get, 'INDEX (as anonymous user to logged in allowed read)', :ok,
                             {remove_auth: true, data_item_count: 0, response_body_content: ['200']})
  end

  get '/projects' do
    prepare_project_anon
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'INDEX (as no access user to anon allowed read)', :ok, {data_item_count: 0, response_body_content: ['200']})
  end

  ################################
  # CREATE
  ################################
  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/name'})
  end

  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/name'})
  end

  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/name'})
  end

  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as no access user)', :created, {expected_json_path: 'data/name'})
  end

  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  post '/projects' do
    body_params
    let(:raw_post) { {'project' => post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # NEW
  ################################

  get '/projects/new' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW (as admin)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/new' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'NEW (as owner)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/new' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW (as writer)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/new' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW (as reader)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/new' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'NEW (as no access user)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/projects/new' do
    standard_request_options(:get, 'NEW (as anonymous user)', :ok, {remove_auth: true, expected_json_path: 'data/name'})
  end

  ################################
  # SHOW
  ################################
  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/name'})
  end

  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/projects/:id' do
    id_params
    let(:id) { project.id }
    standard_request_options(:get, 'SHOW (an anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/projects/:id' do
    id_params
    prepare_project_anon
    let(:id) { project_anon.id }
    standard_request_options(:get, 'SHOW (as anonymous user allowed read)', :ok,
                             {remove_auth: true, expected_json_path: 'data/name', response_body_content: ['200', 'Anon Project']})
  end

  get '/projects/:id' do
    id_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user allowed read)', :ok,
                             {expected_json_path: 'data/name', response_body_content: ['200', 'Logged In Project']})
  end

  get '/projects/:id' do
    id_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    standard_request_options(:get, 'SHOW (as anonymous user to logged in allowed read)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/projects/:id' do
    id_params
    prepare_project_anon
    let(:id) { project_anon.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user to anon allowed read)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  ################################
  # UPDATE
  ################################

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/name', response_body_content: ['New Project name']})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:put, 'UPDATE (as owner)', :ok, {expected_json_path: 'data/name', response_body_content: ['New Project name']})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  put '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)})
  end

  put '/projects/:id' do
    body_params
    prepare_project_anon
    let(:id) { project_anon.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user allowed read)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  put '/projects/:id' do
    body_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as no access user allowed read)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:id' do
    body_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user to logged in allowed read)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  put '/projects/:id' do
    body_params
    prepare_project_anon
    let(:id) { project_anon.id }
    let(:raw_post) { {project: post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as no access user to anon allowed read)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  ################################
  # DESTROY
  ################################

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:delete, 'DESTROY (as owner)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  delete '/projects/:id' do
    body_params
    let(:id) { project.id }
    standard_request_options(:delete, 'DESTROY (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)})
  end

  delete '/projects/:id' do
    body_params
    prepare_project_anon
    let(:id) { project_anon.id }
    standard_request_options(:delete, 'DESTROY (as anonymous user allowed read)', :unauthorized,
                             {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  delete '/projects/:id' do
    body_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user allowed read)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:id' do
    body_params
    prepare_project_logged_in
    let(:id) { project_logged_in.id }
    standard_request_options(:delete, 'DESTROY (as anonymous user to logged in allowed read)', :unauthorized,
                             {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  delete '/projects/:id' do
    body_params
    prepare_project_anon
    let(:id) { project_anon.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user to anon allowed read)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  ################################
  # FILTER
  ################################

  post '/projects/filter' do
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'FILTER (as admin)', :ok,
                             {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  post '/projects/filter' do
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'FILTER (as writer)', :ok, {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  post '/projects/filter' do
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {response_body_content: ['200', 'gen_project'], expected_json_path: 'data/0/name', data_item_count: 1})
  end

  post '/projects/filter' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'FILTER (as no access user)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  post '/projects/filter' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'FILTER (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  post '/projects/filter' do
    standard_request_options(:post, 'FILTER (as anonymous user)', :ok, {remove_auth: true, response_body_content: '200', data_item_count: 0})
  end

  post '/projects/filter' do
    prepare_project_anon
    standard_request_options(:post, 'FILTER (as anonymous user allowed read)', :ok,
                             {remove_auth: true, expected_json_path: 'data/0/name', data_item_count: 1, response_body_content: ['200', 'Anon Project']})
  end

  post '/projects/filter' do
    prepare_project_logged_in
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'FILTER (as no access user allowed read)', :ok,
                             {expected_json_path: 'data/0/name', data_item_count: 1, response_body_content: ['200', 'Logged In Project']})
  end

  post '/projects/filter' do
    prepare_project_logged_in
    standard_request_options(:post, 'FILTER (as anonymous user to logged in allowed read)', :ok,
                             {remove_auth: true, data_item_count: 0, response_body_content: ['200']})
  end

  post '/projects/filter' do
    prepare_project_anon
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'FILTER (as no access user to anon allowed read)', :ok, {data_item_count: 0, response_body_content: ['200']})
  end

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

  context 'filter partial match' do

    get '/projects/filter?direction=desc&filter_name=a&filter_partial_match=partial_match_text&items=35&order_by=createdAt&page=1' do
      let(:authentication_token) { reader_token }
      standard_request_options(:get, 'BASIC FILTER (as reader with filtering, sorting, paging)', :ok, {
          expected_json_path: 'meta/paging/current',
          data_item_count: 0,
          response_body_content: '/projects/filter?direction=desc\u0026filter_name=a\u0026filter_partial_match=partial_match_text\u0026items=35\u0026order_by=createdAt\u0026page=1'
      })
    end

  end

  context 'filter with paging via GET' do

    get '/projects/filter?page=1&items=2' do
      let(:authentication_token) { writer_token }
      let!(:more_projects) {
        # default items per page is 25
        29.times do
          FactoryGirl.create(:project, creator: writer_permission.user)
        end
      }

      standard_request_options(:get, 'BASIC FILTER (as reader with paging)', :ok, {
          expected_json_path: 'meta/paging/current',
          data_item_count: 2,
          response_body_content: [
              '"paging":{"page":1,"items":2,"total":30,"max_page":15',
              '"current":"http://localhost:3000/projects/filter?direction=asc\u0026items=2\u0026order_by=name\u0026page=1"',
              '"previous":null,',
              '"next":"http://localhost:3000/projects/filter?direction=asc\u0026items=2\u0026order_by=name\u0026page=2"'
          ]
      })
    end

  end





end
