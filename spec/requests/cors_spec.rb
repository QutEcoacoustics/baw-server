# frozen_string_literal: true

require 'rails_helper'

describe 'CORS requests' do
  expose_headers = (MediaPoll::HEADERS_EXPOSED + ['X-Archived-At', 'X-Error-Type']).join(', ')
  allow_methods = ['GET', 'POST', 'PUT', 'PATCH', 'HEAD', 'DELETE', 'OPTIONS'].join(', ')

  # have to specify content type header, otherwise it gets set to application/x-www-form-urlencoded

  context 'CORS browser example' do
    headers = {
      'Host' => 'localhost:8080',
      'Connection' => 'keep-alive',
      'Cache-Control' => 'max-age=0',
      'Origin' => 'http://localhost:8080',
      'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36',
      'Access-Control-Request-Headers' => 'accept, content-type',
      'Accept' => '*/*',
      'Referer' => 'http://localhost:8080/listen/234234?start=30&end=60',
      'Accept-Encoding' => 'gzip, deflate, sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Content-Type' => 'text/plain'
    }

    it '1, has the expected CORS response' do
      request_headers = headers.merge({ 'Access-Control-Request-Method' => 'PUT' })
      options '/my_account/prefs', headers: request_headers

      expect_empty_body
      expect(response).to have_http_status(:ok)
      expected_response = {
        'Access-Control-Allow-Origin' => 'http://localhost:8080',
        'Access-Control-Expose-Headers' => expose_headers,
        'Access-Control-Allow-Credentials' => 'true',
        'Access-Control-Allow-Methods' => allow_methods,
        'Access-Control-Allow-Headers' => 'accept, content-type',
        'Access-Control-Max-Age' => '7200'
      }
      expect_headers_to_include(expected_response)
    end

    it '2, has the expected CORS response' do
      request_headers = headers.merge({ 'Access-Control-Request-Method' => 'POST' })
      options '/my_account/prefs', headers: request_headers

      expect_empty_body
      expect(response).to have_http_status(:ok)
      expected_response = {
        'Access-Control-Allow-Origin' => 'http://localhost:8080',
        'Access-Control-Expose-Headers' => expose_headers,
        'Access-Control-Allow-Credentials' => 'true',
        'Access-Control-Allow-Methods' => allow_methods,
        'Access-Control-Allow-Headers' => 'accept, content-type',
        'Access-Control-Max-Age' => '7200'
      }
      expect_headers_to_include(expected_response)
    end
  end

  context 'CORS request' do
    default_headers = {
      'Accept' => 'application/json',
      'Host' => 'localhost:8080',
      'Content-Type' => 'text/plain'
    }

    context 'valid' do
      it 'and works with all headers' do
        headers = default_headers.merge({
          'Origin' => 'http://localhost:3000',
          'Access-Control-Request-Method' => 'GET',
          'Access-Control-Request-Headers' => 'Origin, Content-Type, Accept, Authorization, Token'
        })

        options '/projects', headers: headers
        expect_empty_body
        expect(response).to have_http_status(:ok)
        expected_response = {
          'Access-Control-Allow-Origin' => 'http://localhost:3000',
          'Access-Control-Expose-Headers' => expose_headers,
          'Access-Control-Allow-Credentials' => 'true',
          'Access-Control-Allow-Methods' => allow_methods,
          'Access-Control-Allow-Headers' => 'Origin, Content-Type, Accept, Authorization, Token',
          'Access-Control-Max-Age' => '7200'
        }
        expect_headers_to_include(expected_response)
      end

      it 'and works without Access-Control-Request-Headers' do
        # this seems to be accepted by the rails-cors gem
        headers = default_headers.merge({
          'Origin' => 'http://192.168.0.10:8080',
          'Access-Control-Request-Method' => 'GET'
        })

        options '/projects', headers: headers
        expect_empty_body
        expect(response).to have_http_status(:ok)
        expected_response = {
          'Access-Control-Allow-Origin' => 'http://192.168.0.10:8080',
          'Access-Control-Expose-Headers' => expose_headers,
          'Access-Control-Allow-Credentials' => 'true',
          'Access-Control-Allow-Methods' => allow_methods,
          'Access-Control-Max-Age' => '7200'
        }
        expect_headers_to_include(expected_response)
      end
    end

    context 'is invalid' do
      example 'without Origin' do
        headers = {
          'Access-Control-Request-Method' => 'Origin, Content-Type, Accept, Authorization, Token',
          'Access-Control-Request-Headers' => 'PUT',
          'Accept' => 'application/json'
        }
        options '/projects', headers: headers

        expect(response).to have_http_status(:bad_request)
        expect_error(400, "The request was not valid: CORS preflight request to 'projects' was not valid. Required headers: Origin, Access-Control-Request-Method. Optional headers: Access-Control-Request-Headers.")
      end

      example 'without Access-Control-Request-Method' do
        headers = {
          'Origin' => 'http://localhost:3000',
          'Access-Control-Request-Headers' => 'Origin, Content-Type, Accept, Authorization, Token',
          'Accept' => 'application/json'
        }
        options '/projects', headers: headers

        expect(response).to have_http_status(:bad_request)
        expect_error(400, "The request was not valid: CORS preflight request to 'projects' was not valid. Required headers: Origin, Access-Control-Request-Method. Optional headers: Access-Control-Request-Headers.")
      end

      example 'with Origin that is not allowed' do
        headers = {
          'Origin' => 'http://localhost-not-allowed:3000',
          'Access-Control-Request-Method' => 'GET',
          'Access-Control-Request-Headers' => 'Origin, Content-Type, Accept, Authorization, Token'
        }

        options '/projects', headers: headers
        expect_empty_body
        expect(response).to have_http_status(:ok)
        expected_response = {
          'Access-Control-Allow-Origin' => 'http://localhost-not-allowed:3000',
          'Access-Control-Expose-Headers' => expose_headers,
          'Access-Control-Allow-Credentials' => 'true',
          'Access-Control-Allow-Methods' => allow_methods,
          'Access-Control-Max-Age' => '7200'
        }
        expect(response.headers).not_to match(hash_including(expected_response))
      end
    end
  end
end
