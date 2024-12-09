# frozen_string_literal: true

describe 'AnalysisJobsItem permissions' do
  create_entire_hierarchy

  before do
    analysis_jobs_item.update_column(:status, :queued)
  end

  items_reading = Set[:index, :show, :filter]

  items_others = Set[:create, :destroy, :new, :update]

  with_custom_action(:working, path: '{id}/working', verb: :post, expect: :nothing,
    before: lambda { |_user, _action|
      analysis_jobs_item.update_column(:status, :queued)
    })
  with_custom_action(:finish, path: '{id}/finish', verb: :post, expect: :nothing,
    before: lambda { |_user, _action|
      analysis_jobs_item.update_column(:status, :working)
    })

  actions = Set[:working, :finish]

  fails_with = [:not_found, :forbidden]

  given_the_route '/analysis_jobs/{analysis_jobs_id}/items' do
    {
      analysis_jobs_id: analysis_job.id,
      id: analysis_jobs_item.id
    }
  end

  using_the_factory :analysis_jobs_item

  for_lists_expects do |user, _action|
    case user
    when :admin, :harvester
      AnalysisJobsItem.all
    when :owner, :reader, :writer
      analysis_jobs_item
    else
      []
    end
  end
  send_update_body do
    [{ analysis_jobs_item: {} }, :json]
  end

  send_create_body do
    [{ analysis_jobs_item: {} }, :json]
  end

  the_user(:admin, can_do: items_reading + actions, and_cannot_do: items_others, fails_with:)
  the_user(:harvester, can_do: Set[:show] + actions, and_cannot_do: items_others + Set[:index, :filter], fails_with:)

  # Analysis jobs items are tied to the audio recordings a user has access to
  the_users(:writer, :owner, :reader, can_do: items_reading, and_cannot_do: items_others + actions, fails_with:)

  # No access doesn't have access to any audio
  the_users(:no_access, can_do: items_reading - Set[:show], and_cannot_do: items_others + Set[:show] + actions,
    fails_with:)
  the_users(:anonymous, can_do: items_reading - Set[:show], and_cannot_do: items_others + Set[:show] + actions,
    fails_with: [:unauthorized, :not_found])

  ensures :invalid, cannot: items_reading + items_others + actions, fails_with: [:unauthorized, :not_found]
end

describe 'AnalysisJobsItem anonymous permissions' do
  create_entire_hierarchy

  before do
    analysis_jobs_item.update_column(:status, :queued)

    # allow anonymous access to the project
    Permission.new(creator: owner_user, user: nil, project:, level: :reader, allow_anonymous: true).save!
  end

  items_reading = Set[:index, :show, :filter]

  items_others = Set[:create, :destroy, :new, :update]

  with_custom_action(:working, path: '{id}/working', verb: :post, expect: :nothing,
    before: lambda { |_user, _action|
      analysis_jobs_item.update_column(:status, :queued)
    })
  with_custom_action(:finish, path: '{id}/finish', verb: :post, expect: :nothing,
    before: lambda { |_user, _action|
      analysis_jobs_item.update_column(:status, :working)
    })

  actions = Set[:working, :finish]

  fails_with = [:not_found, :forbidden]

  given_the_route '/analysis_jobs/{analysis_jobs_id}/items' do
    {
      analysis_jobs_id: analysis_job.id,
      id: analysis_jobs_item.id
    }
  end

  using_the_factory :analysis_jobs_item
  for_lists_expects do |user, _action|
    case user
    when :admin, :harvester
      AnalysisJobsItem.all
    when :owner, :reader, :writer, :anonymous
      analysis_jobs_item
    else
      []
    end
  end
  send_update_body do
    [{ analysis_jobs_item: {} }, :json]
  end

  ensures :anonymous, can: items_reading, cannot: items_others + actions, fails_with: [:unauthorized, :not_found]

  the_user(:admin, can_do: items_reading + actions, and_cannot_do: items_others, fails_with:)
  the_user(:harvester, can_do: Set[:show] + actions, and_cannot_do: items_others + Set[:index, :filter], fails_with:)

  # Analysis jobs items are tied to the audio recordings a user has access to
  the_users(:writer, :owner, :reader, can_do: items_reading, and_cannot_do: items_others + actions, fails_with:)

  # No access doesn't have access to any audio
  the_users(:no_access, can_do: items_reading - Set[:show], and_cannot_do: items_others + Set[:show] + actions,
    fails_with:)

  ensures :invalid, cannot: items_reading + items_others + actions, fails_with: [:unauthorized, :not_found]
end
