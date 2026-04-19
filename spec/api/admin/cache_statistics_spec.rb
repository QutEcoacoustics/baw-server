# frozen_string_literal: true

require 'swagger_helper'

describe 'admin/cache_statistics', type: :request do
  prepare_users

  sends_json_and_expects_json
  with_authorization
  for_model Statistics::CacheStatistics

  self.baw_body_name = 'cache_statistics'

  which_has_schema ref(:admin_cache_statistics)

  let!(:audio_stats) { create(:cache_statistics, name: 'audio') }

  path '/admin/cache_statistics' do
    get('list admin/cache_statistics') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/admin/cache_statistics/{id}' do
    get('show admin/cache_statistics/{id}') do
      response(200, 'successful') do
        schema_for_single
        let(:id) { audio_stats.id }
        run_test!
      end
    end
  end
end
