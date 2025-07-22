# frozen_string_literal: true

require 'swagger_helper'

# the stats service does not return a model, and has no C-UD, only -R-- (Read).
describe 'status', type: :request do
  let(:skip_automatic_description) { true }

  path '/status' do
    get 'Gets status' do
      tags 'stats'
      produces 'application/json'
      response '200', 'stats retrieved' do
        schema({
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['good', 'bad']
            },
            timed_out: { type: 'boolean' },
            database: { type: ['boolean', 'string'] },
            redis: { type: 'string' },
            storage: { type: 'string' },
            upload: { type: 'string' },
            batch_analysis: { type: 'string' }
          }
        })

        run_test! do
          expect_json_response
        end
      end
    end
  end
end
