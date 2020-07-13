require 'swagger_helper'

describe 'projects', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Project

  path '/projects/filter' do
    post('filter project') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects' do
    get('list projects') do
      response(200, 'successful') do
        run_test!
      end
    end

    post('create project') do
      response(200, 'successful') do
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

  path '/projects/{id}/edit' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('edit project') do
      response(200, 'successful') do
        let(:id) { '123' }

        run_test!
      end
    end
  end

  path '/projects/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show project') do
      response(200, 'successful') do
        let(:id) { project.id }

        run_test! do |response|
          pp response
        end
      end
    end

    patch('update project') do
      response(200, 'successful') do
        let(:id) { '123' }

        run_test!
      end
    end

    put('update project') do
      response(200, 'successful') do
        let(:id) { '123' }

        run_test!
      end
    end

    delete('delete project') do
      response(200, 'successful') do
        let(:id) { '123' }

        run_test!
      end
    end
  end
end
