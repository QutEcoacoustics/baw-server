require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Public' do

  expose_headers = %w(Content-Length X-Media-Elapsed-Seconds X-Media-Response-From X-Media-Response-Start).join(', ')
  allow_methods = %w(GET POST PUT PATCH HEAD DELETE OPTIONS).join(', ')

  # have to specify content type header, otherwise it gets set to application/x-www-form-urlencoded
  header 'Content-Type', ''

  context 'CORS example' do

    context '1' do

      header 'Host', 'localhost:8080'
      header 'Connection', 'keep-alive'
      header 'Cache-Control', 'max-age=0'
      header 'Access-Control-Request-Method', 'PUT'
      header 'Origin', 'http://localhost:8080'
      header 'User-Agent', 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36'
      header 'Access-Control-Request-Headers', 'accept, content-type'
      header 'Accept', '*/*'
      header 'Referer', 'http://localhost:8080/listen/234234?start=30&end=60'
      header 'Accept-Encoding', 'gzip, deflate, sdch'
      header 'Accept-Language', 'en-US,en;q=0.8'

      http_options_verb '/my_account/prefs' do
        standard_request_options(
            :http_options_verb,
            'OPTIONS /my_account/prefs (example 1)',
            :ok,
            {
                expected_response_has_content: false,
                expected_response_content_type: 'text/plain',
                expected_response_header_values:
                    {
                        'Access-Control-Allow-Origin' => 'http://localhost:8080',
                        'Access-Control-Expose-Headers' => expose_headers,
                        'Access-Control-Allow-Credentials' => 'true',
                        'Access-Control-Allow-Methods' => allow_methods,
                        'Access-Control-Allow-Headers' => 'accept, content-type',
                        'Access-Control-Max-Age' => "1728000",
                        'Content-Type' => 'text/plain'
                    },
                expected_request_header_values:
                    {
                        'Host' => 'localhost:8080',
                        'Connection' => 'keep-alive',
                        'Cache-Control' => 'max-age=0',
                        'Access-Control-Request-Method' => 'PUT',
                        'Origin' => 'http://localhost:8080',
                        'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36',
                        'Access-Control-Request-Headers' => 'accept, content-type',
                        'Accept' => '*/*',
                        'Referer' => 'http://localhost:8080/listen/234234?start=30&end=60',
                        'Accept-Encoding' => 'gzip, deflate, sdch',
                        'Accept-Language' => 'en-US,en;q=0.8',

                        # these headers are added/modified by the framework :/
                        'Content-Type' => '',
                        'Cookie' => ''
                    }
            })
      end
    end

    context '2' do
      header 'Host', 'localhost:8080'
      header 'Connection', 'keep-alive'
      header 'Access-Control-Request-Method', 'POST'
      header 'Origin', 'http://localhost:8080'
      header 'User-Agent', 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36'
      header 'Access-Control-Request-Headers', 'accept, content-type'
      header 'Accept', '*/*'
      header 'Referer', 'http://localhost:8080/listen'
      header 'Accept-Encoding', 'gzip, deflate, sdch'
      header 'Accept-Language', 'en-US,en;q=0.8'

      http_options_verb '/audio_recordings/filter' do
        standard_request_options(
            :http_options_verb,
            'OPTIONS /my_account/prefs (example 2)',
            :ok,
            {
                expected_response_has_content: false,
                expected_response_content_type: 'text/plain',
                expected_response_header_values:
                    {
                        'Access-Control-Allow-Origin' => 'http://localhost:8080',
                        'Access-Control-Expose-Headers' => expose_headers,
                        'Access-Control-Allow-Credentials' => 'true',
                        'Access-Control-Allow-Methods' => allow_methods,
                        'Access-Control-Allow-Headers' => 'accept, content-type',
                        'Access-Control-Max-Age' => "1728000",
                        'Content-Type' => 'text/plain'
                    },
                expected_request_header_values:
                    {
                        'Host' => 'localhost:8080',
                        'Connection' => 'keep-alive',
                        'Access-Control-Request-Method' => 'POST',
                        'Origin' => 'http://localhost:8080',
                        'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36',
                        'Access-Control-Request-Headers' => 'accept, content-type',
                        'Accept' => '*/*',
                        'Referer' => 'http://localhost:8080/listen',
                        'Accept-Encoding' => 'gzip, deflate, sdch',
                        'Accept-Language' => 'en-US,en;q=0.8',

                        # these headers are added/modified by the framework :/
                        'Content-Type' => '',
                        'Cookie' => ''
                    }
            })
      end
    end

  end

  context 'CORS request' do

    header 'Accept', '*/*'
    header 'Host', 'localhost:8080'

    context 'valid' do

      context 'with all headers' do
        header 'Origin', :header_origin
        header 'Access-Control-Request-Method', :header_method
        header 'Access-Control-Request-Headers', :header_headers
        http_options_verb '/projects' do
          let(:header_origin) { 'http://localhost:3000' }
          let(:header_method) { 'GET' }
          let(:header_headers) { 'Origin, Content-Type, Accept, Authorization, Token' }
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (all headers)',
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
                          'Access-Control-Max-Age' => "1728000",
                          'Content-Type' => 'text/plain'
                      },
                  expected_request_header_values:
                      {
                          'Origin' => 'http://localhost:3000',
                          'Access-Control-Request-Method' => 'GET',
                          'Access-Control-Request-Headers' => 'Origin, Content-Type, Accept, Authorization, Token',

                          # defaults and framework-specified headers
                          'Accept' => '*/*',
                          'Host' => 'localhost:8080',
                          'Content-Type' => '',
                          'Cookie' => ''
                      },
              })
        end
      end

      context 'without Access-Control-Request-Headers' do
        # this seems to be accepted by the rails-cors gem
        header 'Origin', 'http://0.0.0.0:3000'
        header 'Access-Control-Request-Method', 'GET'
        http_options_verb '/projects' do
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (without request-headers)',
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
                          'Access-Control-Max-Age' => "1728000",
                          'Content-Type' => 'text/plain'
                      },
                  expected_request_header_values:
                      {
                          'Origin' => 'http://0.0.0.0:3000',
                          'Access-Control-Request-Method' => 'GET',

                          # defaults and framework-specified headers
                          'Accept' => '*/*',
                          'Host' => 'localhost:8080',
                          'Content-Type' => '',
                          'Cookie' => ''
                      },
              })
        end
      end

    end

    context 'invalid' do

      context 'without Origin' do
        header 'Access-Control-Request-Method', 'Origin, Content-Type, Accept, Authorization, Token'
        header 'Access-Control-Request-Headers', 'PUT'
        http_options_verb '/projects' do
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (without Origin)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

      context 'without Access-Control-Request-Method' do
        header 'Origin', 'http://localhost:3000'
        header 'Access-Control-Request-Headers', 'Origin, Content-Type, Accept, Authorization, Token'
        http_options_verb '/projects' do
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (without request-method)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

      context 'with Origin that is not allowed' do
        header 'Origin', 'http://localhost-not-allowed:3000'
        header 'Access-Control-Request-Method', 'GET'
        header 'Access-Control-Request-Headers','Origin, Content-Type, Accept, Authorization, Token'
        http_options_verb '/projects' do
          standard_request_options(
              :http_options_verb,
              'OPTIONS /projects (with invalid Origin)',
              :bad_request,
              {
                  response_body_content: "The request was not valid: CORS preflight request to 'projects' was not valid."
              })
        end
      end

    end

  end

end