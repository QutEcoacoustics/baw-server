# frozen_string_literal: true

describe 'user confirmations', type: :request do
  describe 'GET /my_account/confirmation' do
    let(:user) { create(:unconfirmed_user) }

    it 'confirms the account and redirects to the client home page' do
      get user_confirmation_path(confirmation_token: user.confirmation_token)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(Settings.client_routes.home_url.to_s)
      expect(user.reload).to be_confirmed
    end
  end
end
