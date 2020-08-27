require 'swagger_helper'

describe 'saved_searches', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model SavedSearch
  which_has_schema ref(:saved_search)

  path '/saved_searches/filter' do
    post('filter saved_search') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/saved_searches' do
    get('list saved_searches') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create saved_search') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/saved_searches/new' do
    get('new saved_search') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/saved_searches/{id}' do
    with_id_route_parameter
    let(:id) { saved_search.id }

    get('show saved_search') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(saved_search)
        end
      end
    end

    patch('can\'t update saved_search') do
      model_sent_as_parameter_in_body
      response(404, 'not found') do
        schema nil
        auto_send_model
        run_test! do
          expect_error(404, 'Could not find the requested page.')
        end
      end
    end

    put('can\'t update saved_search') do
      model_sent_as_parameter_in_body
      response(404, 'not found') do
        schema nil
        auto_send_model
        run_test! do
          expect_error(404, 'Could not find the requested page.')
        end
      end
    end

    delete('delete saved_search') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
