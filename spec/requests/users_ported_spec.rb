# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/user_accounts_spec.rb.

describe 'User account functionality (ported)' do
  prepare_users

  it 'persists nested preference values without changing other users' do
    preferences = {
      volume: 1,
      muted: false,
      auto_play: false,
      visualize: { hide_images: true, hide_fixed: false }
    }
    original_preferences = reader_user.preferences

    put '/my_account/prefs',
      params: { user_account: preferences },
      **api_with_body_headers(writer_token)

    expect_success
    expect(api_data).to include(id: writer_user.id, preferences:)
    expect(writer_user.reload.preferences).to eq(preferences.deep_stringify_keys)
    expect(reader_user.reload.preferences).to eq(original_preferences)
  end

  describe 'filtering with a projection' do
    let(:filter_body) {
      {
        filter: { id: { in: [writer_user.id] } },
        projection: { include: [:id, :user_name] }
      }
    }

    context 'when the selected user has a timezone' do
      before do
        writer_user.update!(tzinfo_tz: 'Australia/Sydney', rails_tz: 'Sydney')
      end

      it 'retains computed timezone information outside the selected columns' do
        post '/user_accounts/filter', params: filter_body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(1)
        expect_has_projection(only: ['id', 'user_name'])
        expect(api_data.first).to include(
          id: writer_user.id,
          user_name: writer_user.user_name,
          timezone_information: hash_including(
            identifier: 'Australia/Sydney',
            identifier_alt: 'Sydney',
            friendly_identifier: 'Australia - Sydney',
            utc_offset: a_kind_of(Numeric)
          )
        )
      end
    end

    context 'when the selected user has no timezone' do
      before do
        writer_user.update!(tzinfo_tz: nil, rails_tz: nil)
      end

      it 'retains a null timezone field' do
        post '/user_accounts/filter', params: filter_body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(1)
        expect_has_projection(only: ['id', 'user_name'])
        expect(api_data.first).to include(
          id: writer_user.id,
          user_name: writer_user.user_name,
          timezone_information: nil
        )
      end
    end

    it 'includes private computed fields for administrators' do
      writer_user.update!(last_seen_at: nil, preferences: nil)

      post '/user_accounts/filter', params: filter_body, **api_with_body_headers(admin_token)

      expect_success
      expect_number_of_items(1)
      expect_has_projection(only: ['id', 'user_name'])
      expect(api_data.first).to include(
        id: writer_user.id,
        user_name: writer_user.user_name,
        last_seen_at: nil,
        preferences: nil
      )
    end
  end
end
