# frozen_string_literal: true

describe 'Admin::SiteSettings permissions' do
  # we're using a string route parameter,
  # so we have to override the expectations in the default actions
  with_custom_action(:show, path: '{id}', verb: :get, expect: lambda { |_user, _action|
    expect(api_data).to include(id: nil, name: 'batch_analysis_remote_enqueue_limit')
  })

  with_custom_action(:update, path: '{id}', verb: :put, expect: lambda { |_user, _action|
    expect(api_data).to include(id: an_instance_of(Integer), name: 'batch_analysis_remote_enqueue_limit')
  }, body: :update)

  prepare_users

  given_the_route '/admin/site_settings' do
    {
      id: 'batch_analysis_remote_enqueue_limit'
    }
  end

  send_update_body do
    {
      site_setting: {
        value: 99
      }
    }
  end

  send_create_body do
    {
      site_setting: {
        name: 'batch_analysis_remote_enqueue_limit',
        value: 99
      }
    }
  end

  for_lists_expects do |user, _action|
    case user
    when :admin
      Admin::SiteSetting.load_all_settings
    else
      []
    end
  end

  defined_actions = everything - [:new, :filter]

  the_users :admin, can_do: defined_actions, and_cannot_do: []
  the_users :owner, :reader, :writer, :no_access, :harvester,
    can_do: nothing, and_cannot_do: defined_actions

  the_users :anonymous, :invalid, can_do: nothing, and_cannot_do: defined_actions, fails_with: :unauthorized

  ensures(*all_users, cannot: [:new, :filter], fails_with: :not_found)
end
