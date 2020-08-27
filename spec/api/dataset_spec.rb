require 'swagger_helper'

describe 'datasets', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Dataset
  which_has_schema ref(:dataset)

  path '/datasets/filter' do
    post('filter dataset') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/datasets' do
    get('list datasets') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create dataset') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/datasets/new' do
    get('new dataset') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/datasets/{id}' do
    with_id_route_parameter
    let(:id) { dataset.id }

    get('show dataset') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(dataset)
        end
      end
    end

    patch('update dataset') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(dataset)
        end
      end
    end

    put('update dataset') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(dataset)
        end
      end
    end

    delete('can\'t delete a dataset') do
      response(404, 'not found') do
        schema nil
        run_test! do
          expect_error(404, 'Could not find the requested page.')
        end
      end
    end
  end
end
