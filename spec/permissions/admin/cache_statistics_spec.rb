# frozen_string_literal: true

describe 'Admin::CacheStatistics permissions' do
  prepare_users

  given_the_route '/admin/cache_statistics' do
    {
      id: cache_statistic.id
    }
  end

  let!(:cache_statistic) { create(:cache_statistics) }

  for_lists_expects do |user, _action|
    case user
    when :admin
      Statistics::CacheStatistics.all
    else
      []
    end
  end

  defined_actions = [:index, :show, :filter]

  the_users :admin, can_do: defined_actions, and_cannot_do: []
  the_users :owner, :reader, :writer, :no_access, :harvester,
    can_do: nothing, and_cannot_do: defined_actions

  the_users :anonymous, :invalid, can_do: nothing, and_cannot_do: defined_actions, fails_with: :unauthorized

  ensures(*all_users, cannot: [:new, :create, :update, :destroy], fails_with: :not_found)
end
