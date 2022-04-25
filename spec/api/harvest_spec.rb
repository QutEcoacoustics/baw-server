# frozen_string_literal: true

require 'swagger_helper'

describe 'harvests', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  sends_json_and_expects_json
  with_authorization
  for_model Harvest
  which_has_schema ref(:harvest)

  path '/harvests/filter' do
    post('filter harvest') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/harvests' do
    get('list harvests') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create harvest') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          { harvest: { streaming: true, project_id: project.id } }
        end
        run_test!
      end
    end
  end

  path '/harvests/new' do
    get('new harvest') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/harvests/{id}' do
    with_id_route_parameter
    let(:id) { harvest.id }

    get('show harvest') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    patch('update harvest') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          { harvest: { mappings: nil } }
        end
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    put('update harvest') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          { harvest: { mappings: nil } }
        end
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    delete('delete harvest') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end

describe 'harvests (nested)', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  sends_json_and_expects_json
  with_authorization
  for_model Harvest
  which_has_schema ref(:harvest)

  let(:project_id) { project.id }

  with_route_parameter(:project_id)

  path '/projects/{project_id}/harvests/filter' do
    post('filter harvest') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/projects/{project_id}/harvests' do
    get('list harvests') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create harvest') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          { harvest: { streaming: true } }
        end
        run_test!
      end
    end
  end

  path '/projects/{project_id}/harvests/new' do
    get('new harvest') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{project_id}/harvests/{id}' do
    with_route_parameter(:project_id)
    with_id_route_parameter
    let(:id) { harvest.id }

    get('show harvest') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    patch('update harvest') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          { harvest: { mappings: nil } }
        end
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    put('update harvest') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model do
          { harvest: { mappings: nil } }
        end
        run_test! do
          expect_id_matches(harvest)
        end
      end
    end

    delete('delete harvest') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
