# frozen_string_literal: true

require 'swagger_helper'

# the stats service does not return a model, and has no C-UD, only -R-- (Read).
describe 'stats', type: :request do
  let(:skip_automatic_description) { true }

  path '/stats' do
    get 'Gets stats' do
      tags 'stats'
      produces 'application/json'
      response '200', 'stats retrieved' do
        schema allOf: [
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
