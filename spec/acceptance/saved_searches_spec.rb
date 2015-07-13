require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'SavedSearches' do

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
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)

    @write_permission = FactoryGirl.create(:write_permission, creator: @admin_user, user: @writer_user)
    @read_permission = FactoryGirl.create(:read_permission, creator: @admin_user, user: @reader_user, project: @write_permission.project)

    @saved_search_query = {
        filter: {
            'projects.id' => {
                in: [@write_permission.project.id]
            }
        }
    }
    @saved_search = FactoryGirl.create(:saved_search, creator: @writer_user, projects: [@write_permission.project])
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@writer_user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@reader_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:post_attributes) { {name: 'saved search name'} }

  ################################
  # LIST
  ################################
  get '/saved_searches' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 1})
  end

  get '/saved_searches' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 3})
  end

  get '/saved_searches' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 5})
  end

  get '/saved_searches' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed_token)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/saved_searches' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # CREATE
  ################################
  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Show
  ################################
  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/stored_query'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: %w(data/created_at data/stored_query)})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: %w(data/updated_at data/stored_query)})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Update
  ################################
  put '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :not_found, {expected_json_path: 'meta/error/info/original_http_method'})
  end

  patch '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:patch, 'UPDATE (as reader)', :not_found, {expected_json_path: 'meta/error/info/original_http_method'})
  end

  ################################
  # Destroy
  ################################
  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as user)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DESTROY (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  delete '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @saved_search.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  #####################
  # Filter
  #####################

  post '/saved_searches/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        filter: {
            stored_query: {
                contains: 'comment'
            }
        },
        projection: {
            include: %w(id name stored_query)
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
                                      expected_json_path: 'meta/filter/stored_query',
                                      data_item_count: 3,
                                      regex_match: /"stored_query":"the writer stored query"/,
                                      response_body_content: "\"stored_query\":\"comment text"
                                  })
  end

end