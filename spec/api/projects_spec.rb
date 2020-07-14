require 'swagger_helper'

describe 'projects', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Project
  which_has_schema do
    {
      type: 'object',
      properties: {
        id: { type: 'integer' },
        name: { type: 'string' },
        description: { type: 'string' },
        notes: { type: 'object' },
        creator_id: { type: 'integer' },
        updater_id: { type: 'integer' }
      }
    }
  end

  path '/projects/filter' do
    post('filter project') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          assert_at_least_one_item
        end
      end
    end
  end

  path '/projects' do
    get('list projects') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          assert_at_least_one_item
        end
      end
    end

    post('create project') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model { attributes_for(:project) }
        run_test!
      end
    end
  end

  path '/projects/new' do
    get('new project') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'
    let(:id) { project.id }

    get('show project') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          assert_id_matches(project)
        end
      end
    end

    patch('update project') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model { project }
        run_test! do
          assert_id_matches(project)
        end
      end
    end

    put('update project') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        send_model { project }
        run_test! do
          assert_id_matches(project)
        end
      end
    end

    delete('delete project') do
      response(204, 'successful') do
        schema nil
        run_test! do
          assert_no_response
        end
      end
    end
  end
end
