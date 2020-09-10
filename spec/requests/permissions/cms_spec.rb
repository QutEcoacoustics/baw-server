# frozen_string_literal: true

require 'rails_helper'

describe 'CMS permissions' do
  prepare_users
  create_standard_cms_pages

  given_the_route '/cms' do
    {
      cms_path: 'credits'
    }
  end
  send_create_body do
    [{}, :json]
  end
  send_update_body do
    [{}, :json]
  end

  custom_index = { path: '', verb: :get, expect: lambda { |_user, _action|
    expect(api_response).to include({
      slug: 'index'
    })
  }, action: :index }
  custom_show = { path: '{cms_path}', verb: :get, expect: lambda { |_user, _action|
    expect(api_response).to include({
      slug: 'credits'
    })
  }, action: :show }

  # The CMS API is provided by a third party service and does not conform to our standard API conventions.
  # Thus we use  `ensures` to bypass the extra validation offered by the `the_user` method.
  #
  # Any user can read any page at any time. However, no mutation is available
  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
          can: [custom_index, custom_show],
          cannot: [:create, :update, :destroy],
          fails_with: :not_found

  # invalid however triggers a middleware response the occurs before even the CMS module
  ensures :invalid,
          can: [],
          cannot: [custom_index, custom_show, :create, :update, :destroy],
          fails_with: :unauthorized
end

describe 'CMS backend permissions' do
  prepare_users

  before(:all) do
    load Rails.root / 'db' / 'cms_seeds' / 'cms_seeds.rb'
  end

  given_the_route '/admin/cms/sites' do
    {}
  end
  send_create_body do
    [{}, :json]
  end
  send_update_body do
    [{}, :json]
  end

  custom_index = { path: '', verb: :get, expect: lambda { |_user, _action|
    expect(response_body).to include("<body class='c-comfy-admin-cms-sites a-index' id='comfy'>")
  }, action: :index }

  let(:request_accept) {
    '*/*'
  }

  # The CMS API is provided by a third party service and does not conform to our standard API conventions.
  # Thus we use  `ensures` to bypass the extra validation offered by the `the_user` method.
  #
  # Only admin can see the backend
  ensures :admin,
          can: [custom_index]

  # invalid however triggers a middleware response the occurs before even the CMS module
  ensures :owner, :writer, :reader, :no_access, :harvester, :anonymous,
          can: [],
          cannot: [custom_index],
          fails_with: :unauthorized

  # invalid however triggers a middleware response the occurs before even the CMS module
  ensures :invalid,
          can: [],
          cannot: [custom_index],
          fails_with: :unauthorized
end
