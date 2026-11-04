# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/dataset_items_spec.rb.

describe 'Dataset item permissions (ported acceptance cases)' do
  create_audio_recordings_hierarchy
  prepare_dataset
  prepare_dataset_item
  create_no_access_hierarchy

  let!(:another_dataset) { create(:dataset, creator: owner_user) }
  let!(:another_dataset_item) {
    create(:dataset_item, creator: admin_user, dataset: another_dataset, audio_recording:)
  }

  given_the_route '' do
    { dataset_id: dataset.id, id: dataset_item.id }
  end

  send_create_body do
    [{ dataset_item: { audio_recording_id: audio_recording.id, start_time_seconds: 1, end_time_seconds: 234 } }, :json]
  end
  send_update_body do
    [{ dataset_item: { end_time_seconds: 234 } }, :json]
  end

  # Root-relative paths let the same matrix exercise both historical filter aliases.
  with_custom_action :index, path: 'datasets/{dataset_id}/items', verb: :get, expect: :list
  with_custom_action :show, path: 'datasets/{dataset_id}/items/{id}', verb: :get, expect: :single
  with_custom_action :new, path: 'datasets/{dataset_id}/items/new', verb: :get, expect: :template
  with_custom_action :create, path: 'datasets/{dataset_id}/items', verb: :post, expect: :created, body: :create
  with_custom_action :update, path: 'datasets/{dataset_id}/items/{id}', verb: :put, expect: :single, body: :update
  with_custom_action :destroy, path: 'datasets/{dataset_id}/items/{id}', verb: :delete, expect: :nothing
  with_custom_action :filter, path: 'datasets/{dataset_id}/items/filter', verb: :post, expect: :list
  with_custom_action :nested_filter, path: 'datasets/{dataset_id}/dataset_items/filter', verb: :post, expect: :list
  with_custom_action :shallow_filter, path: 'dataset_items/filter', verb: :post, expect: :list
  with_custom_action :next_for_me, path: 'datasets/{dataset_id}/dataset_items/next_for_me', verb: :get, expect: :list

  for_lists_expects do |user, action|
    expected = case user
               when :admin
                 [dataset_item, no_access_dataset_item, default_dataset_item, another_dataset_item]
               when :owner, :writer, :reader
                 [dataset_item, default_dataset_item, another_dataset_item]
               else
                 []
               end
    expected = expected.select { |item| item.dataset_id == dataset.id } unless action == :shallow_filter
    expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
    expected
  end

  list_actions = listing | [:nested_filter, :shallow_filter, :next_for_me]
  the_user :admin, can_do: everything
  the_users :owner, :writer, :reader, can_do: list_actions | [:show], and_cannot_do: writing
  the_user :no_access, can_do: list_actions, and_cannot_do: writing | [:show]
  the_user :harvester, can_do: nothing, and_cannot_do: everything
  the_user :anonymous, can_do: list_actions, and_cannot_do: writing | [:show], fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
