# frozen_string_literal: true

require 'swagger_helper'

# the cms service is provided by a third party, hence its API
# varies from our common format.
describe 'stats', type: :request do
  let(:skip_automatic_description) { true }

  path '/stats' do
    get 'Gets stats' do
      tags 'stats'
      produces 'application/json'
      response '200', 'stats retrieved' do
        schema schema allOf: [
          { '$ref' => '#/components/schemas/standard_response' },
          {
            type: 'object',
            properties: {
              data: { '$ref' => '#/components/schemas/stats' }
            }
          }
        ]

        run_test! do
          expect_json_response
        end
      end
    end
  end
end
