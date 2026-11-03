# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/questions_spec.rb.

describe 'Questions permissions (ported)' do
  create_entire_hierarchy

  given_the_route '/questions' do
    { id: question.id }
  end

  send_create_body do
    [{ question: attributes_for(:question, study_ids: [study.id]) }, :json]
  end
  send_update_body do
    [{ question: { text: 'Updated question' } }, :json]
  end

  for_lists_expects { |_user, _action| Question.all }

  the_user :admin, can_do: everything
  the_users :owner, :writer, :reader, :no_access, can_do: reading
  the_user :anonymous, can_do: [:new], fails_with: :unauthorized
  the_user :harvester, can_do: nothing
  the_user :invalid, can_do: nothing, fails_with: :unauthorized
end
