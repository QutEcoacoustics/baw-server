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

  # create extra scripts - grouping really needs to be tested with multiple items
  let!(:extra_scripts) {
    [
        FactoryGirl.create(:script, version: 1.0, id: 1234),
        FactoryGirl.create(:script, version: 1.5, group_id: 1234),
        FactoryGirl.create(:script, version: 1.6, group_id: 1234)
    ]
  }

  let(:body_attributes) {
    FactoryGirl.attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id).to_json
  }

  ################################
  # INDEX
  ################################

  get '/scripts' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {
        expected_json_path: 'data/0/analysis_identifier',
        data_item_count: 4
    })
  end

  get '/scripts' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {
        expected_json_path: 'data/0/analysis_identifier',
        data_item_count: 4
    })
  end

  get '/scripts' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {
        expected_json_path: [
            'data/0/name',
            'data/0/description',
            'data/0/analysis_identifier',
            'data/0/version',
            'data/0/group_id',
            'data/0/creator_id',
            'data/0/executable_settings',
            'data/0/executable_settings_media_type',
            'data/0/is_last_version',
            'data/0/is_first_version',
        ],
        data_item_count: 4
    })
  end

  get '/scripts/' do
    let(:authentication_token) { reader_token }
    parameter :filter_is_last_version, "Only return the last version for each group"
    let(:filter_is_last_version) { true }

    standard_request_options(
        :get,
        'INDEX (as reader with querystring for latest version)',
        :ok,
        {
            expected_json_path: [
                'meta/filter/is_last_version/eq',
            ],
            data_item_count: 2,
            response_body_content: [
                '"is_first_version":{"eq":true}',
                '"is_last_version":true',
                '"version":1.6,"group_id":1234',
                '"version":%{version},"group_id":%{group_id}',
            ]
        },
        &proc { |context, opts|
          opts[:response_body_content][3] = opts[:response_body_content][3] % {
              version: context.script[:version],
              group_id: context.script[:group_id]
          }
        }
    )
  end

  get '/scripts' do
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'INDEX (as other)', :ok, {
        expected_json_path: 'data/0/analysis_identifier',
        data_item_count: 4
    })
  end

  get '/scripts' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {
        expected_json_path: get_json_error_path(:confirm)
    })
  end

  get '/scripts' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {
        expected_json_path: get_json_error_path(:sign_in)
    })
  end

  ################################
  # SHOW
  ################################

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {
        expected_json_path: ['data/analysis_identifier', 'data/executable_settings']
    })
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {
        expected_json_path: ['data/analysis_identifier', 'data/executable_settings']
    })
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {
        expected_json_path: [
            'data/name',
            'data/description',
            'data/analysis_identifier',
            'data/version',
            'data/group_id',
            'data/creator_id',
            'data/executable_settings',
            'data/executable_settings_media_type',
            'data/is_last_version',
            'data/is_first_version',
        ]
    })
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other)', :ok, {
        expected_json_path: ['data/analysis_identifier', 'data/executable_settings']
    })
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {
        expected_json_path: get_json_error_path(:confirm)
    })
  end

  get '/scripts/:id' do
    scripts_id_param
    let(:id) { script.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {
        expected_json_path: get_json_error_path(:sign_in)
    })
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
        data_item_count: 4,
        response_body_content: [
            '"analysis_identifier":{"contains":" identifier "}',
            '"executable_settings":"']
    })
  end

  post '/scripts/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        filter: {
            is_last_version: {
                eq: true
            },
            is_first_version: {
                eq: true
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader, filtering by is_last_version, is_first_version)', :ok, {
        expected_json_path: [
            'meta/filter/is_last_version/eq',
            'meta/filter/is_first_version/eq'
        ],
        data_item_count: 1,
        response_body_content: [
            '"is_last_version":{"eq":true}',
            '"is_first_version":{"eq":true}',
            '"is_last_version":true',
            '"is_first_version":true',
            '"executable_settings":"'
        ]
    })
  end
end