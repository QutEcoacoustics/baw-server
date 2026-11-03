# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/studies_spec.rb.

describe 'Studies permissions (ported)' do
  create_entire_hierarchy

  given_the_route '/studies' do
    { id: study.id }
  end

  send_create_body do
    [{ study: attributes_for(:study, dataset_id: dataset.id) }, :json]
  end
  send_update_body do
    [{ study: { name: 'Updated study' } }, :json]
  end

  for_lists_expects { |_user, _action| Study.all }

  the_user :admin, can_do: everything
  the_users :owner, :writer, :reader, :no_access, can_do: reading
  the_user :anonymous, can_do: reading, fails_with: :unauthorized
  the_user :harvester, can_do: nothing
  the_user :invalid, can_do: nothing, fails_with: :unauthorized
end
