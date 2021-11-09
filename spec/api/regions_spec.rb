# frozen_string_literal: true

require 'swagger_helper'

describe 'regions', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Region
  which_has_schema ref(:region)

  path '/regions/filter' do
    post('filter region') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/regions' do
    get('list regions') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create region') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/regions/new' do
    get('new region') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/regions/{id}' do
    with_id_route_parameter
    let(:id) { region.id }

    get('show region') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    patch('update region') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    put('update region') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    delete('delete region') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end

describe 'regions (nested)', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Region
  which_has_schema ref(:region)

  let(:project_id) { project.id }

  with_route_parameter(:project_id)

  path '/projects/{project_id}/regions/filter' do
    post('filter region') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/projects/{project_id}/regions' do
    get('list regions') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create region') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/projects/{project_id}/regions/new' do
    get('new region') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{project_id}/regions/{id}' do
    with_route_parameter(:project_id)
    with_id_route_parameter
    let(:id) { region.id }

    get('show region') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    patch('update region') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    put('update region') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(region)
        end
      end
    end

    delete('delete region') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
