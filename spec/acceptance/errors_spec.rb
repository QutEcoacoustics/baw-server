require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'


# https://github.com/zipmark/rspec_api_documentation
resource 'Errors' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  around(:each) do |example|
    stored_request_local = Rails.application.config.consider_all_requests_local
    Rails.application.config.consider_all_requests_local = false

    stored_show_exceptions = Rails.application.config.action_dispatch.show_exceptions
    Rails.application.config.action_dispatch.show_exceptions = true
    example.run
    Rails.application.config.consider_all_requests_local = stored_request_local
    Rails.application.config.action_dispatch.show_exceptions = stored_show_exceptions
  end

  get '/does_not_exist' do
    standard_request('ROUTE (does not exist)', 404, 'meta/error/original_route', true, 'does_not_exist')
  end

  get '/does_not_exist/42' do
    standard_request('ROUTE (does not exist with id)', 404, 'meta/error/original_route', true, 'does_not_exist/42')
  end

  get '/test_exceptions?exception_class=ActiveRecord::RecordNotFound' do
    standard_request('ROUTE (does not exist with id)', 404, 'meta/error/details', true, 'Could not find the requested item')
  end

  get '/test_exceptions?exception_class=CustomErrors::ItemNotFoundError' do
    standard_request('ERROR', 404, 'meta/error/details', true, 'Could not find the requested item')
  end

  get '/test_exceptions?exception_class=ActiveRecord::RecordNotUnique' do
    standard_request('ERROR', 409, 'meta/error/details', true, 'The item must be unique')
  end

  get '/test_exceptions?exception_class=CustomErrors::UnsupportedMediaTypeError' do
    standard_request('ERROR', 415, 'meta/error/details', true, 'The format of the request is not supported')
  end

  get '/test_exceptions?exception_class=CustomErrors::NotAcceptableError' do
    standard_request('ERROR', 406, 'meta/error/details', true, 'None of the acceptable response formats are available')
  end

  get '/test_exceptions?exception_class=CustomErrors::UnprocessableEntityError' do
    standard_request('ERROR', 422, 'meta/error/details', true, 'The request could not be understood')
  end

  get '/test_exceptions?exception_class=ActionController::BadRequest' do
    standard_request('ERROR', 400, 'meta/error/details', true, 'The request was not valid')
  end

  get '/test_exceptions?exception_class=CanCan::AccessDenied' do
    standard_request('ERROR', 401, 'meta/error/links/confirm your account', true, 'sign_in')
  end

  get '/test_exceptions?exception_class=CustomErrors::RoutingArgumentError' do
    standard_request('ERROR', 404, 'meta/error/original_route', true, 'Could not find the requested page')
  end

  get '/test_exceptions?exception_class=CustomErrors::FilterArgumentError' do
    standard_request('ERROR', 400, 'meta/error/details', true, 'Filter parameters were not valid')
  end

end