require 'rails_helper'
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

  create_entire_hierarchy

  let(:saved_search_query) { {
      filter: {
          'projects.id' => {
              in: [writer_permission.project.id]
          }
      }
  } }

  let(:example_stored_query) { {uuid: {eq: audio_recording.uuid}} }
  let(:post_attributes) {
    {
        name: 'saved search name',
        description: 'I\'m a description!',
        stored_query: example_stored_query
    }
  }

  context 'list' do

    get '/saved_searches' do
      let(:authentication_token) { admin_token }
      standard_request_options(:get, 'LIST (as admin)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 1})
    end

    get '/saved_searches' do
      let(:authentication_token) { writer_token }
      standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 1})
    end

    get '/saved_searches' do
      let(:authentication_token) { reader_token }
      standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 1})
    end

    get '/saved_searches' do
      let(:authentication_token) { other_token }
      standard_request_options(:get, 'LIST (as other)', :ok, {expected_json_path: 'data', data_item_count: 0})
    end

    get '/saved_searches' do
      let(:authentication_token) { unconfirmed_token }
      standard_request_options(:get, 'LIST (as unconfirmed_token)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
    end

    get '/saved_searches' do
      let(:authentication_token) { invalid_token }
      standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
    end

  end

  context 'create' do

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/stored_query', data_item_count: 1})
    end

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/stored_query', data_item_count: 1})
    end

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { reader_token }
      standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/stored_query', data_item_count: 1})
    end

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { other_token }
      standard_request_options(:post, 'CREATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { unconfirmed_token }
      standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
    end

    post '/saved_searches' do
      let(:raw_post) { {saved_search: post_attributes}.to_json }
      let(:authentication_token) { invalid_token }
      standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
    end

  end

  context 'show' do
    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { admin_token }
      standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: %w(data/analysis_job_ids data/stored_query), data_item_count: 1})
    end

    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { writer_token }
      standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/stored_query', data_item_count: 1})
    end

    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { reader_token }
      standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/stored_query', data_item_count: 1})
    end

    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { other_token }
      standard_request_options(:get, 'SHOW (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { unconfirmed_token }
      standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
    end

    get '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { invalid_token }
      standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
    end
  end

  context 'update' do
    put '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (as writer)', :not_found, {expected_json_path: 'meta/error/info/original_http_method'})
    end

    patch '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
      let(:authentication_token) { reader_token }
      standard_request_options(:patch, 'UPDATE (as reader)', :not_found, {expected_json_path: 'meta/error/info/original_http_method'})
    end
  end

  context 'delete' do

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { admin_token }
      standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
    end

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { writer_token }
      standard_request_options(:delete, 'DESTROY (as writer)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
    end

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { reader_token }
      standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { other_token }
      standard_request_options(:delete, 'DESTROY (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { unconfirmed_token }
      standard_request_options(:delete, 'DESTROY (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
    end

    delete '/saved_searches/:id' do
      parameter :id, 'Requested saved search id (in path/route)', required: true
      let(:id) { saved_search.id }
      let(:authentication_token) { invalid_token }
      standard_request_options(:delete, 'DESTROY (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
    end

  end

  context 'filter' do

    post '/saved_searches/filter' do
      let(:authentication_token) { reader_token }
      let(:raw_post) { {
          filter: {
              stored_query: {
                  eq: {uuid: {eq: 'blah blah'}}.to_json
              }
          },
          projection: {
              include: %w(id name stored_query)
          }
      }.to_json }
      standard_request_options(:post, 'FILTER (as reader)', :ok, {
          expected_json_path: 'meta/filter/stored_query',
          data_item_count: 1,
          response_body_content: '"stored_query":'+{uuid: {eq: 'blah blah'}}.to_json
      })
    end
  end

end