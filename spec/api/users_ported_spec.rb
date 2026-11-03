# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/user_accounts_spec.rb.

require 'swagger_helper'

describe 'User account API (ported)', type: :request do
  prepare_users

  sends_json_and_expects_json
  with_authorization
  for_model User
  which_has_schema({
    type: :object,
    required: [:id, :user_name],
    properties: {
      id: { type: :integer, readOnly: true },
      user_name: { type: :string }
    }
  })

  path '/user_accounts' do
    get 'list user accounts as JSON' do
      consumes nil

      response 406, 'only the HTML index is available' do
        schema ref(:error_response)

        run_test! do
          expect_error(:not_acceptable, "This resource is not available in this format 'application/json'.")
        end
      end
    end
  end

  path '/user_accounts/{id}' do
    with_id_route_parameter
    let(:id) { reader_user.id }

    get 'show a user account' do
      consumes nil

      response 200, 'successful' do
        schema_for_single
        run_test! { expect_id_matches(reader_user) }
      end
    end

    put 'update a user account' do
      model_sent_as_parameter_in_body

      response 200, 'successful' do
        schema_for_single
        send_model { { user: { user_name: 'ported profile' } } }
        run_test! { expect_id_matches(reader_user) }
      end
    end
  end

  path '/my_account' do
    get 'show the current user account' do
      consumes nil

      response 200, 'successful' do
        schema_for_single
        run_test! { expect_id_matches(admin_user) }
      end
    end
  end

  path '/my_account/prefs' do
    put 'update the current user preferences' do
      parameter name: :preferences_payload, in: :body, schema: {
        type: :object,
        required: [:user_account],
        properties: {
          user_account: {
            type: :object,
            required: [:volume, :muted],
            properties: {
              volume: { type: :number },
              muted: { type: :boolean }
            }
          }
        }
      }

      let(:preferences_payload) { { user_account: { volume: 1, muted: false } } }

      response 200, 'successful' do
        schema Api::Schema.standard_single_response({
          type: :object,
          required: [:id, :user_name, :preferences],
          properties: {
            id: { type: :integer },
            user_name: { type: :string },
            preferences: {
              type: :object,
              required: [:volume, :muted],
              properties: {
                volume: { type: :number },
                muted: { type: :boolean }
              }
            }
          }
        })

        run_test! { expect_id_matches(admin_user) }
      end
    end
  end

  path '/user_accounts/filter' do
    post 'filter user accounts' do
      response 200, 'successful' do
        schema_for_many
        run_test! { expect_at_least_one_item }
      end
    end
  end
end
