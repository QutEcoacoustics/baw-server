require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Public' do

  # set header
  header 'Accept', 'application/json; q=1.0, text/plain; q=0.5'
  header 'Content-Type', 'text/plain'
  header 'Authorization', :authentication_token

  expose_headers = %w(Content-Length X-Media-Elapsed-Seconds X-Media-Response-From X-Media-Response-Start).join(', ')
  allow_methods = %w(GET POST PUT PATCH HEAD DELETE OPTIONS).join(', ')

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # as well as a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission)
  end

  context 'CORS request' do

    context 'valid' do

      context 'with all headers' do
        header 'Origin', :header_origin
        header 'Access-Control-Request-Method', :header_method
        header 'Access-Control-Request-Headers', :header_headers
        http_options_verb '/projects' do
          let(:authentication_token) { writer_token }
          let(:header_origin) { 'http://localhost:3000' }
          let(:header_method) { 'GET' }
          let(:header_headers) { 'Origin, Content-Type, Accept, Authorization, Token' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (as writer)',
              :ok,
              {
                  expected_response_has_content: false,
                  expected_response_content_type: 'text/plain',
                  expected_response_header_values:
                      {
                          'Access-Control-Allow-Origin' => 'http://localhost:3000',
                          'Access-Control-Expose-Headers' => expose_headers,
                          'Access-Control-Allow-Credentials' => 'true',
                          'Access-Control-Allow-Methods' => allow_methods,
                          'Access-Control-Allow-Headers' => 'Origin, Content-Type, Accept, Authorization, Token',
                          'Access-Control-Max-Age' => "1728000"
                      },
                  expected_request_header_values:
                      {
                          'Origin' => 'http://localhost:3000',
                          'Access-Control-Request-Method' => 'GET',
                          'Access-Control-Request-Headers' => 'Origin, Content-Type, Accept, Authorization, Token'
                      },
              })
        end
      end

      context 'without Access-Control-Request-Headers' do
        # this seems to be accepted by the rails-cors gem
        header 'Origin', :header_origin
        header 'Access-Control-Request-Method', :header_method
        http_options_verb '/projects' do
          let(:authentication_token) { writer_token }
          let(:header_origin) { 'http://0.0.0.0:3000' }
          let(:header_method) { 'GET' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (as writer)',
              :ok,
              {
                  expected_response_has_content: false,
                  expected_response_content_type: 'text/plain',
                  expected_response_header_values:
                      {
                          'Access-Control-Allow-Origin' => 'http://0.0.0.0:3000',
                          'Access-Control-Expose-Headers' => expose_headers,
                          'Access-Control-Allow-Credentials' => 'true',
                          'Access-Control-Allow-Methods' => allow_methods,
                          'Access-Control-Max-Age' => "1728000"
                      },
                  expected_request_header_values:
                      {
                          'Origin' => 'http://0.0.0.0:3000',
                          'Access-Control-Request-Method' => 'GET'
                      },
              })
        end
      end

    end

    context 'invalid' do

      context 'without Origin' do
        header 'Access-Control-Request-Method', :header_method
        header 'Access-Control-Request-Headers', :header_headers
        http_options_verb '/projects' do
          let(:authentication_token) { writer_token }
          let(:header_method) { 'GET' }
          let(:header_headers) { 'Origin, Content-Type, Accept, Authorization, Token' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (as writer)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

      context 'without Access-Control-Request-Method' do
        header 'Origin', :header_origin
        header 'Access-Control-Request-Headers', :header_headers
        http_options_verb '/projects' do
          let(:authentication_token) { writer_token }
          let(:header_origin) { 'http://localhost:3000' }
          let(:header_headers) { 'Origin, Content-Type, Accept, Authorization, Token' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (as writer)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

      context 'with Origin that is not allowed' do
        header 'Origin', :header_origin
        header 'Access-Control-Request-Method', :header_method
        header 'Access-Control-Request-Headers', :header_headers
        http_options_verb '/projects' do
          let(:authentication_token) { writer_token }
          let(:header_origin) { 'http://localhost-not-allowed:3000' }
          let(:header_method) { 'GET' }
          let(:header_headers) { 'Origin, Content-Type, Accept, Authorization, Token' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (as writer)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

    end

  end

end