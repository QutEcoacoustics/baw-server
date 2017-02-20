require 'rails_helper'
require 'rspec/mocks'

describe UserAccountsController do

  # make sure it can recover from bad input
  describe 'proper timezones data' do
    let(:user_bad_tz) {
      user = FactoryGirl.build(:user, tzinfo_tz: 'Australia/Sydney', rails_tz: 'Sydney')
      user.save!(validate: false)
      user
    }

    before(:each) do
      request.env['HTTP_AUTHORIZATION'] = Creation::Common.create_user_token(user_bad_tz)
    end

    describe 'GET my_account' do
      it 'converts proper timezones' do
        old_values = [user_bad_tz.tzinfo_tz, user_bad_tz.rails_tz]

        response = get :my_account, {format: :json}
        body = JSON.parse(response.body)

        expect(body['data']['timezone_information']['identifier']).to eq('Australia/Sydney')


        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq(['Australia - Sydney', 'Sydney'])
      end
    end

    describe 'PUT update' do

      it 'converts proper timezones when updating user_account\'s preferences' do
        old_values = [user_bad_tz.tzinfo_tz, user_bad_tz.rails_tz]

        post_json = {"volume": 1, "muted": false, "auto_play": false, "visualize": {
            "hide_images": true,
            "hide_fixed": false}
        }

        response = put :modify_preferences, {user_account: post_json, format: :json}
        expect(response).to have_http_status(:ok)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq(['Australia - Sydney', 'Sydney'])
      end
    end
  end

  describe 'bad timezones data' do
    let(:user_bad_tz) {
      user = FactoryGirl.build(:user, tzinfo_tz: 'person@domain.com', rails_tz: 'person@domain.com')
      user.save!(validate: false)
      user
    }

    before(:each) do
      request.env['HTTP_AUTHORIZATION'] = Creation::Common.create_user_token(user_bad_tz)
    end

    describe 'GET my_account' do
      it 'should delete bad timezones' do
        old_values = [user_bad_tz.tzinfo_tz, user_bad_tz.rails_tz]

        response = get :my_account, {format: :json}
        body = JSON.parse(response.body)

        expect(body["timezone_information"]).to be(nil)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq([nil, nil])
      end
    end

    describe 'PUT update' do

      it "deletes bad timezones when updating the requested user_account's preferences" do
        old_values = [user_bad_tz.tzinfo_tz, user_bad_tz.rails_tz]

        post_json = {"volume": 1, "muted": false, "auto_play": false, "visualize": {
            "hide_images": true,
            "hide_fixed": false}
        }

        response = put :modify_preferences, {user_account: post_json, format: :json}
        expect(response).to have_http_status(:ok)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq([nil, nil])
      end
    end
  end

  describe 'archivable' do
    before(:each) do
      # see https://github.com/plataformatec/devise/wiki/How-To:-Test-controllers-with-Rails-3-and-4-(and-RSpec)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @admin = FactoryGirl.create(:admin)
      sign_in(@admin, scope: :user) # sign_in(scope, resource)
    end

    it_behaves_like :a_delete_api_call, User, :allow_archive  # delete must be done manually by admin

    it 'cannot archive admin' do
      response = delete :destroy, id: @admin.id, format: :json
      body = JSON.parse(response.body)
      expect(response.status).to eq(400)
      expect(User.find(@admin.id).deleted?).to be_falsey
      expect(body['meta']['error']['details']).to eq('The request was not valid: Cannot delete this account.')
    end

    context 'with associations' do
      create_entire_hierarchy

      let(:delete_api_model) {
        owner_user
      }

      it_behaves_like :a_delete_api_call, User, :allow_archive # delete must be done manually by admin
    end

  end

  it 'standard user cannot archive own account through DELETE to /user_accounts/:id' do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    user = FactoryGirl.create(:user)
    sign_in(user, scope: :user)
    response = delete :destroy, id: user.id
    expect(response.status).to eq(403)
    expect(User.with_deleted.find(user.id).deleted?).to be_falsey
    expect(response.headers['X-Error-Type']).to eq('Can Can/Access Denied')
  end

end