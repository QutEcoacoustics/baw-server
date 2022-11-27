# frozen_string_literal: true

require 'swagger_helper'

describe 'security', type: :request do
  let(:skip_automatic_description) { true }

  create_audio_recordings_hierarchy

  path '/security' do
    post 'create a new session' do
      tags 'security'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          anyOf: [
            {
              type: :object,
              required: [:email, :password],
              properties: {
                email: { type: :string },
                password: { type: :string }
              }
            },
            {
              type: :object,
              required: [:login, :password],
              properties: {
                login: { type: :string },
                password: { type: :string }
              }
            }
          ]
        },
        required: [:user]
      }

      response '200', 'session created' do
        let(:user) { { user: { email: admin_user.email, password: Settings.admin_user.password } } }
        schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: { '$ref' => '#/components/schemas/security' }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end

    delete 'logout' do
      with_authorization
      tags 'security'
      produces 'application/json'

      response '200', 'session destroyed' do
        schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: {
                type: :object,
                properties: {
                  message: { type: :string },
                  user_name: { type: :string }
                },
                required: [:message, :user_name]
              }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end
  end

  path '/security/user' do
    get 'Gets the current session (with a cookie)' do
      with_cookie

      tags 'security'

      produces 'application/json'
      response '200', 'session retrieved' do
        schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: { '$ref' => '#/components/schemas/security' }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end

    get 'Gets the current session (with an auth token)' do
      with_authorization
      tags 'security'

      produces 'application/json'
      response '200', 'session retrieved' do
        schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: { '$ref' => '#/components/schemas/security' }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end

    get 'Gets the current session (with a JWT)' do
      with_jwt
      tags 'security'

      produces 'application/json'
      response '200', 'session retrieved' do
        schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: { '$ref' => '#/components/schemas/security' }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end
  end
end
