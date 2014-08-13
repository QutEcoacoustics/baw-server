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

  get '/does_not_exist' do
    standard_request('ROUTE (does not exist)' ,404,'meta/error/original_route', true, 'does_not_exist')
  end

  get '/does_not_exist/42' do
    standard_request('ROUTE (does not exist with id)' ,404,'meta/error/original_route', true, 'does_not_exist/42')
  end
 

  # /test_exceptions?exception_class=CustomErrors::RoutingArgumentError
  # /test_exceptions?exception_class=ActiveRecord::RecordNotFound
  # /test_exceptions?exception_class=ActionView::MissingTemplate
  # /test_exceptions?exception_class=ArgumentError
  # /test_exceptions?exception_class=CanCan::AccessDenied

  # ActiveRecord::RecordNotFound, with: :record_not_found_response
  # CustomErrors::ItemNotFoundError, with: :item_not_found_response
  # ActiveRecord::RecordNotUnique, with: :record_not_unique_response
  # CustomErrors::UnsupportedMediaTypeError, with: :unsupported_media_type_response
  # CustomErrors::NotAcceptableError, with: :not_acceptable_response
  # CustomErrors::UnprocessableEntityError, with: :unprocessable_entity_response
  # ActiveResource::BadRequest, with: :bad_request_response
end