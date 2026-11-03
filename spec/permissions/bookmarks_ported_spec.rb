# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/bookmarks_spec.rb.

describe 'Bookmark permissions (ported)' do
  create_audio_recordings_hierarchy

  let!(:bookmark) {
    create(:bookmark, creator: writer_user, audio_recording:,
      name: 'the_expected_name', category: 'the_expected_category')
  }

  given_the_route '/bookmarks' do
    { id: bookmark.id }
  end
  using_the_factory :bookmark, factory_args: -> { { audio_recording_id: audio_recording.id } }

  with_custom_action :name_filter, path: '?filter_name=the_expected_name', verb: :get, expect: :list
  with_custom_action :category_filter, path: '?filter_category=the_expected_category', verb: :get, expect: :list

  filtered_lists = Set[:name_filter, :category_filter]

  for_lists_expects do |user, _action|
    expected = user == :writer ? [bookmark] : []
    expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
    expected
  end

  # Even admins only list bookmarks they created or updated.
  the_users :admin, :writer, can_do: everything | filtered_lists
  the_users :owner, :reader, can_do: listing | creation | filtered_lists, and_cannot_do: Set[:show] | mutation
  the_user :no_access, can_do: listing | filtered_lists, and_cannot_do: not_listing - filtered_lists

  the_user :harvester, can_do: nothing, and_cannot_do: everything | filtered_lists
  the_users :anonymous, :invalid, can_do: nothing, and_cannot_do: everything | filtered_lists,
    fails_with: :unauthorized
end
