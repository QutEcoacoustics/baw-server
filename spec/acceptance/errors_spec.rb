# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Errors' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  extend RequestSpecHelpers::ExampleGroup
  render_error_responses

  get '/does_not_exist' do
    standard_request_options(:get, 'ROUTE (does not exist)', :not_found,
      { expected_json_path: 'meta/error/info/original_route', response_body_content: 'does_not_exist' })
  end

  get '/does_not_exist/42' do
    standard_request_options(:get, 'ROUTE (does not exist with id)', :not_found,
      { expected_json_path: 'meta/error/info/original_route', response_body_content: 'does_not_exist/42' })
  end

  get '/test_exceptions?exception_class=ActiveRecord::RecordNotFound' do
    standard_request_options(:get, 'ROUTE (does not exist with id)', :not_found,
      { expected_json_path: 'meta/error/details', response_body_content: 'Could not find the requested item' })
  end

  get '/test_exceptions?exception_class=CustomErrors::ItemNotFoundError' do
    standard_request_options(:get, 'ERROR', :not_found,
      { expected_json_path: 'meta/error/details', response_body_content: 'Could not find the requested item' })
  end

  get '/test_exceptions?exception_class=ActiveRecord::RecordNotUnique' do
    standard_request_options(:get, 'ERROR', :conflict,
      { expected_json_path: 'meta/error/details', response_body_content: 'The item must be unique' })
  end

  get '/test_exceptions?exception_class=CustomErrors::UnsupportedMediaTypeError' do
    standard_request_options(:get, 'ERROR', :unsupported_media_type,
      { expected_json_path: 'meta/error/details', response_body_content: 'The format of the request is not supported' })
  end

  get '/test_exceptions?exception_class=CustomErrors::NotAcceptableError' do
    standard_request_options(:get, 'ERROR', :not_acceptable,
      { expected_json_path: 'meta/error/details', response_body_content: 'None of the acceptable response formats are available' })
  end

  get '/test_exceptions?exception_class=CustomErrors::UnprocessableEntityError' do
    standard_request_options(:get, 'ERROR', :unprocessable_entity,
      { expected_json_path: 'meta/error/details', response_body_content: 'The request could not be understood' })
  end

  get '/test_exceptions?exception_class=ActionController::BadRequest' do
    standard_request_options(:get, 'ERROR', :bad_request,
      { expected_json_path: 'meta/error/details', response_body_content: 'The request was not valid' })
  end

  get '/test_exceptions?exception_class=CanCan::AccessDenied' do
    standard_request_options(:get, 'ERROR', :unauthorized,
      { expected_json_path: get_json_error_path(:confirm), response_body_content: 'sign_in' })
  end

  get '/test_exceptions?exception_class=CustomErrors::RoutingArgumentError' do
    standard_request_options(:get, 'ERROR', :not_found,
      { expected_json_path: 'meta/error/info/original_route', response_body_content: 'Could not find the requested page' })
  end

  get '/test_exceptions?exception_class=CustomErrors::FilterArgumentError' do
    standard_request_options(:get, 'ERROR', :bad_request,
      { expected_json_path: 'meta/error/details', response_body_content: 'Filter parameters were not valid' })
  end

  head '/test_exceptions?exception_class=BawAudioTools::Exceptions::AudioToolError' do
    standard_request_options(:head, 'ERROR AudioToolError', :internal_server_error,
      {
        expected_response_has_content: false,
        expected_response_header_values_match: false,
        expected_response_header_values:
              {
                'X-Error-Type' => 'Baw Audio Tools/Exceptions/Audio Tool Error'
              }
      })
  end

  get '/test_exceptions?exception_class=BawAudioTools::Exceptions::AudioToolError' do
    standard_request_options(:get, 'ERROR AudioToolError', :internal_server_error,
      {
        expected_json_path: 'meta/error/details',
        response_body_content: ['Internal Server Error',
                                'Purposeful exception raised for testing']
      })
  end
end
