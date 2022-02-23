require 'swagger_helper'

describe 'permissions', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Permission, factory: :read_permission
  which_has_schema ref(:permission)

  let(:project_id) { project.id }

  path '/projects/{project_id}/permissions/filter' do
    with_route_parameter(:project_id)

    post('filter permission') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/projects/{project_id}/permissions' do
    with_route_parameter(:project_id)

    get('list permissions') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create permission') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/projects/{project_id}/permissions/new' do
    with_route_parameter(:project_id)

    get('new permission') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{project_id}/permissions/{id}' do
    with_route_parameter(:project_id)

    with_id_route_parameter
    let(:id) { reader_permission.id }

    get('show permission') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(reader_permission)
        end
      end
    end

    patch('update permission') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(reader_permission)
        end
      end
    end

    put('update permission') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(reader_permission)
        end
      end
    end

    delete('delete permission') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
