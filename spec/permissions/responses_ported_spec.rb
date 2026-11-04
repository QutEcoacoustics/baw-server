# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/responses_spec.rb.

describe 'Responses permissions (ported)' do
  create_entire_hierarchy

  given_the_route '/responses' do
    { id: user_response.id }
  end

  send_create_body do
    [
      {
        response: attributes_for(
          :response, study_id: study.id, question_id: question.id, dataset_item_id: dataset_item.id
        )
      },
      :json
    ]
  end

  # Only admins and the responder (reader created both responses) see responses;
  # everyone else gets an empty list.
  for_lists_expects do |user, _action|
    [:admin, :reader].include?(user) ? [default_user_response, user_response] : []
  end

  # Responses are immutable: PUT is routed to a 405 for everyone, covered in requests/responses_spec.rb.
  do_not_check_permissions_for PermissionsHelpers::ExampleGroup::STANDARD_USERS, [:update]

  the_user :admin, can_do: everything_but_update, and_cannot_do: []
  the_user :reader, can_do: reading | creation, and_cannot_do: [:destroy]
  the_users :owner, :writer, can_do: listing | creation, and_cannot_do: [:show, :destroy]
  the_user :no_access, can_do: listing, and_cannot_do: [:create, :show, :destroy]
  the_user :anonymous, can_do: [:new], and_cannot_do: everything_but_update - [:new],
    fails_with: :unauthorized
  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update
  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end
