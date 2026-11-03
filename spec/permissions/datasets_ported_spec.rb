# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/datasets_spec.rb.

describe 'Dataset permissions (ported acceptance cases)' do
  prepare_users
  prepare_dataset

  given_the_route '/datasets' do
    { id: dataset.id }
  end
  using_the_factory :dataset
  with_custom_action :filter, path: 'filter', verb: :post, expect: :list

  for_lists_expects do |_user, _action|
    expected = [default_dataset, dataset]
    expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
    expected
  end

  # There is no destroy route; its 404 is already documented by spec/api/dataset_spec.rb.
  do_not_check_permissions_for PermissionsHelpers::ExampleGroup::STANDARD_USERS, [:destroy]
  available = everything - [:destroy]

  the_users :admin, :owner, can_do: available, and_cannot_do: nothing
  the_users :writer, :reader, :no_access, can_do: reading | creation, and_cannot_do: [:update]
  the_user :harvester, can_do: nothing, and_cannot_do: available
  the_user :anonymous, can_do: reading, and_cannot_do: [:create, :update], fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: available, fails_with: :unauthorized
end
