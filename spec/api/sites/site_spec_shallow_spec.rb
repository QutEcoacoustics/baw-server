# frozen_string_literal: true

require 'swagger_helper'

describe 'sites (shallow)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Site
  which_has_schema ref(:site)

  path '/sites/filter' do
    post('filter site') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/sites' do
    get('list sites') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create site') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          {
            site: {
              name: 'site name 2',
              description: 'site description 2',
              notes: 'note number 2',
              region_id: region.id,
              project_ids: [project.id]
            }
          }
        end
        run_test!
      end
    end
  end

  path '/sites/new' do
    get('new site') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/sites/{id}' do
    with_id_route_parameter
    let(:id) { site.id }

    get('show site') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    patch('update site') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    put('update site') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    delete('delete site') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
