require 'rails_helper'

describe Users::RegistrationsController do

  it 'cannot archive admin' do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    @admin = FactoryGirl.create(:admin)
    sign_in(@admin, scope: :user) # sign_in(scope, resource)
    response = delete :destroy, id: @admin.id, format: :json
    body = JSON.parse(response.body)
    expect(response.status).to eq(400)
    expect(User.find(@admin.id).deleted?).to be_falsey
    expect(body['meta']['error']['details']).to eq('The request was not valid: Cannot delete this account.')
  end

  it 'standard user can archive own account through DELETE to /my_account' do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    user = FactoryGirl.create(:user)
    sign_in(user, scope: :user)
    response = delete :destroy, id: user.id
    expect(response.status).to eq(302)
    expect(response.flash['notice']).to eq(I18n.t('devise.registrations.destroyed'))
    expect(User.with_deleted.find(user.id).deleted?).to be_truthy
    expect(response.headers['Location']).to eq(root_url)
  end
end