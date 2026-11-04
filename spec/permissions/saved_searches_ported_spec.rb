# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/saved_searches_spec.rb.

describe 'Saved search permissions (ported)' do
  create_audio_recordings_hierarchy
  prepare_saved_search

  given_the_route '/saved_searches' do
    { id: saved_search.id }
  end
  using_the_factory :saved_search, factory_args: -> { { stored_query: { uuid: { eq: audio_recording.uuid } } } }

  # There is no update route; both verbs are already documented in spec/api/saved_search_spec.rb.
  do_not_check_permissions_for(all_users, [:update])

  # Saved searches have an empty new-item template, unlike most resources.
  with_custom_action :new, path: 'new', verb: :get,
    expect: ->(_user, _action) { expect(api_result[:data]).to be_a(Hash) }

  for_lists_expects do |user, _action|
    expected = [:admin, :owner, :writer, :reader].include?(user) ? [saved_search] : []
    expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
    expected
  end

  the_users :admin, :writer, can_do: everything_but_update, and_cannot_do: nothing
  the_users :owner, :reader, can_do: reading | creation, and_cannot_do: [:destroy]
  the_user :no_access, can_do: listing, and_cannot_do: [:show, :create, :destroy]

  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update
  the_user :anonymous, can_do: [:index, :filter], and_cannot_do: [:new, :show, :create, :destroy],
    fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end
