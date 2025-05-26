# frozen_string_literal: true

describe 'Admin::SiteSettings' do
  prepare_users

  describe 'when the setting does not exist' do
    let(:common_attributes) {
      {
        id: nil,
        name: 'batch_analysis_remote_enqueue_limit',
        value: Settings.batch_analysis.remote_enqueue_limit,
        description: 'The maximum number of items allowed to be enqueued at once for batch analysis.',
        type_specification: 'NilClass | Integer'
      }
    }

    it 'can list site settings' do
      get '/admin/site_settings', **api_headers(admin_token)

      expect_success
      expect(api_data).to a_collection_including(
        a_hash_including(
          **common_attributes
        )
      )
    end

    it 'can show a site setting' do
      get '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes
      )
    end

    it 'can create a site setting' do
      params = {
        site_setting: {
          name: 'batch_analysis_remote_enqueue_limit',
          value: 42
        }
      }

      post '/admin/site_settings', params:, **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes,
        id: an_instance_of(Integer),
        value: 42
      )
    end

    it 'can update a site setting' do
      # NOTE: the value doesn't actually exist, but we can still update it
      params = {
        site_setting: {
          value: 42
        }
      }
      put '/admin/site_settings/batch_analysis_remote_enqueue_limit', params:, **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes,
        id: an_instance_of(Integer),
        value: 42
      )
    end

    it 'can upsert a site setting' do
      params = {
        site_setting: {
          name: 'batch_analysis_remote_enqueue_limit',
          value: 42
        }
      }
      put '/admin/site_settings', params:, **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes,
        id: an_instance_of(Integer),
        value: 42
      )
    end

    it 'can delete a site setting' do
      # this is weird, since we load defaults if a setting doesn't exist,
      # you can always delete a setting, even if it doesn't exist
      delete '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)
      expect_no_content

      # to prove the point:
      delete '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)
      expect_no_content

      # but we can still pull back a default value
      get '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)
      expect_success
      expect(api_data).to include(
        **common_attributes
      )
    end
  end

  describe 'when the setting exists' do
    before do
      Admin::SiteSetting.batch_analysis_remote_enqueue_limit = 69 # nice
    end

    let(:common_attributes) {
      {
        id: an_instance_of(Integer),
        name: 'batch_analysis_remote_enqueue_limit',
        value: 69,
        description: 'The maximum number of items allowed to be enqueued at once for batch analysis.',
        type_specification: 'NilClass | Integer'
      }
    }

    it 'can list site settings' do
      get '/admin/site_settings', **api_headers(admin_token)

      expect_success
      expect(api_data).to a_collection_including(
        a_hash_including(
          **common_attributes
        )
      )
    end

    it 'can show a site setting' do
      get '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes
      )
    end

    it 'can create a site setting' do
      params = {
        site_setting: {
          name: 'batch_analysis_remote_enqueue_limit',
          value: 42
        }
      }

      post '/admin/site_settings', params:, **api_with_body_headers(admin_token)

      expect_error(
        :unprocessable_content,
        'Record could not be saved',
        {
          name: ['has already been taken']
        }
      )
    end

    it 'can update a site setting' do
      params = {
        site_setting: {
          value: 42
        }
      }
      put '/admin/site_settings/batch_analysis_remote_enqueue_limit', params:, **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes,
        value: 42
      )
    end

    it 'can upsert a site setting' do
      params = {
        site_setting: {
          name: 'batch_analysis_remote_enqueue_limit',
          value: 42
        }
      }
      put '/admin/site_settings', params:, **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to include(
        **common_attributes,
        id: an_instance_of(Integer),
        value: 42
      )
    end

    it 'can delete a site setting' do
      delete '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)
      expect_success

      # but we can still pull back a default value
      get '/admin/site_settings/batch_analysis_remote_enqueue_limit', **api_headers(admin_token)
      expect_success
      expect(api_data).to include(
        **common_attributes,
        id: nil,
        value: Settings.batch_analysis.remote_enqueue_limit
      )
    end
  end

  it 'validates the type of the setting' do
    params = {
      site_setting: {
        name: 'batch_analysis_remote_enqueue_limit',
        value: 'not an integer'
      }
    }

    put '/admin/site_settings', params:, **api_with_body_headers(admin_token)

    expect_error(
      :unprocessable_content,
      'Record could not be saved',
      {
        value: ['must be of type NilClass | Integer']
      }
    )
  end

  it 'responds appropriately when asking for a non-existent setting' do
    get '/admin/site_settings/non_existent_setting', **api_headers(admin_token)

    expect_error(
      :not_found,
      'Could not find the requested item.'
    )
  end
end
