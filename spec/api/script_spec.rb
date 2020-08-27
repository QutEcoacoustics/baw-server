require 'swagger_helper'

describe 'scripts', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Script
  which_has_schema ref(:script)

  path '/scripts/filter' do
    post('filter script') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/scripts' do
    get('list scripts') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    # NOT IMPLEMENTED YET IN CONTROLLER
    #   post('create script') do
    #     model_sent_as_parameter_in_body
    #     response(201, 'successful') do
    #       schema_for_single
    #       auto_send_model
    #       run_test!
    #     end
    #   end
    # end

    # path '/scripts/new' do
    #   get('new script') do
    #     response(200, 'successful') do
    #       run_test!
    #     end
    #   end
    # end

    path '/scripts/{id}' do
      with_id_route_parameter
      let(:id) { script.id }

      get('show script') do
        response(200, 'successful') do
          schema_for_single
          run_test! do
            expect_id_matches(script)
          end
        end
      end

      # NOT YET IMPLEMENTED IN CONTROLLER
      # patch('update script') do
      #   model_sent_as_parameter_in_body
      #   response(200, 'successful') do
      #     schema_for_single
      #     auto_send_model
      #     run_test! do
      #       expect_id_matches(script)
      #     end
      #   end
      # end

      # put('update script') do
      #   model_sent_as_parameter_in_body
      #   response(200, 'successful') do
      #     schema_for_single
      #     auto_send_model
      #     run_test! do
      #       expect_id_matches(script)
      #     end
      #   end
      # end

      # delete('delete script') do
      #   response(204, 'successful') do
      #     schema nil
      #     run_test! do
      #       expect_empty_body
      #     end
      #   end
    end
  end
end
