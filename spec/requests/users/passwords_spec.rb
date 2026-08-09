# frozen_string_literal: true

describe 'user passwords', type: :request do
  describe 'PUT /my_account/password' do
    let(:user) { create(:confirmed_user) }
    let(:reset_password_token) { user.send(:set_reset_password_token) }

    it 'updates the password and redirects to the client home page' do
      put user_password_path, params: {
        user: {
          reset_password_token: reset_password_token,
          password: 'new password',
          password_confirmation: 'new password'
        }
      }

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(Settings.client_routes.home_url.to_s)
      expect(user.reload.valid_password?('new password')).to be true
    end
  end
end
