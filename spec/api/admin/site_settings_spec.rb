# frozen_string_literal: true

require 'swagger_helper'

describe 'admin/site_settings', type: :request do
  prepare_users

  sends_json_and_expects_json
  with_authorization
  for_model Admin::SiteSetting

  self.baw_body_name = 'site_setting_attributes'

  which_has_schema ref(:admin_site_setting)

  path '/admin/site_settings' do
    get('list admin/site_settings') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create admin/site_setting') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          {
            site_setting: {
              name: 'batch_analysis_remote_enqueue_limit',
              value: 99
            }
          }
        end
        run_test!
      end
    end

    path '/admin/site_settings/batch_analysis_remote_enqueue_limit' do
      get('show admin/site_setting/{name}') do
        response(200, 'successful') do
          schema_for_single
          run_test!
        end
      end

      patch('update admin/site_setting/{name}') do
        model_sent_as_parameter_in_body
        response(200, 'successful') do
          schema_for_single
          send_model do
            {
              site_setting: {
                value: 99
              }
            }
          end
          run_test!
        end
      end

      put('create or update admin/site_setting/{name}') do
        before do
          Admin::SiteSetting.batch_analysis_remote_enqueue_limit = 1
        end

        model_sent_as_parameter_in_body
        response(200, 'successful') do
          schema_for_single
          send_model do
            {
              site_setting: {
                value: 99
              }
            }
          end
          run_test!
        end
      end

      delete('delete admin/site_setting') do
        response(204, 'successful') do
          run_test!
        end
      end
    end
  end
end
