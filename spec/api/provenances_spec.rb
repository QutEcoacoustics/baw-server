# frozen_string_literal: true

require 'swagger_helper'

describe 'provenances', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Provenance
  which_has_schema ref(:provenance)

  path '/provenances/filter' do
    post('filter provenance') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/provenances' do
    get('list provenances') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create provenance') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/provenances/new' do
    get('new provenance') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/provenances/{id}' do
    with_id_route_parameter
    let(:id) { provenance.id }

    get('show provenance') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(provenance)
        end
      end
    end

    patch('update provenance') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(provenance)
        end
      end
    end

    put('update provenance') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(provenance)
        end
      end
    end

    delete('delete provenance') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
