require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def scripts_id_param
  parameter :id, 'Script id in request url', required: true
end

resource 'Scripts' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  let(:body_attributes) { FactoryGirl.attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id).to_json }

  ################################
  # INDEX
  ################################

  get '/scripts' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {expected_json_path: 'data/0/analysis_identifier', data_item_count: 1})
  end

  get '/scripts' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {expected_json_path: 'data/0/analysis_identifier', data_item_count: 1})
  end

  get '/scripts' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {expected_json_path: 'data/0/analysis_identifier', data_item_count: 1})
  end

  get '/scripts' do
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'INDEX (as other)', :ok, {expected_json_path: 'data/0/analysis_identifier', data_item_count: 1})
  end

  get '/scripts' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/scripts' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # SHOW
  ################################

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: ['data/analysis_identifier', 'data/executable_settings']})
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: ['data/analysis_identifier', 'data/executable_settings']})
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: ['data/analysis_identifier', 'data/executable_settings']})
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other)', :ok, {expected_json_path: ['data/analysis_identifier', 'data/executable_settings']})
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # FILTER
  ################################

  post '/scripts/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        filter: {
            analysis_identifier: {
                contains: ' identifier '
            },
            executable_settings_media_type: {
                contains: 'text/plain'
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
        expected_json_path: [
            'meta/filter/analysis_identifier/contains',
            'meta/filter/executable_settings_media_type/contains'
        ],
        data_item_count: 1,
        response_body_content: [
            '"analysis_identifier":{"contains":" identifier "}',
            '"executable_settings":"']
    })
  end

end