# frozen_string_literal: true


require 'rspec/mocks'

describe UserAccountsController do
  # make sure it can recover from bad input
  describe 'proper timezones data' do
    let(:user_bad_tz) {
      user = FactoryBot.build(:user, tzinfo_tz: 'Australia - Sydney', rails_tz: 'Sydney')
      user.save!(validate: false)
      user
    }

    before(:each) do
      request.env['HTTP_AUTHORIZATION'] = Creation::Common.create_user_token(user_bad_tz)
    end

    describe 'GET my_account' do
      it 'converts proper timezones' do
        old_values = ['Australia - Sydney', user_bad_tz.rails_tz]

        response = get :my_account, { format: :json }
        body = JSON.parse(response.body)

        expect(body['data']['timezone_information']['identifier']).to eq('Australia/Sydney')

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq(['Australia/Sydney', 'Sydney'])
      end
    end

    describe 'PUT update' do
      it 'converts proper timezones when updating user_account\'s preferences' do
        old_values = ['Australia - Sydney', user_bad_tz.rails_tz]

        post_json = { "volume": 1, "muted": false, "auto_play": false, "visualize": {
          "hide_images": true,
          "hide_fixed": false
        } }

        response = put :modify_preferences, params: { user_account: post_json, format: :json }
        expect(response).to have_http_status(:ok)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq(['Australia/Sydney', 'Sydney'])
      end
    end
  end

  describe 'bad timezones data' do
    let(:user_bad_tz) {
      user = FactoryBot.build(:user, tzinfo_tz: 'person@domain.com', rails_tz: 'person@domain.com')
      user.save!(validate: false)
      user
    }

    before(:each) do
      request.env['HTTP_AUTHORIZATION'] = Creation::Common.create_user_token(user_bad_tz)
    end

    describe 'GET my_account' do
      it 'should deleted bad timezones' do
        old_values = ['Australia - Sydney', user_bad_tz.rails_tz]

        response = get :my_account, { format: :json }
        body = JSON.parse(response.body)

        expect(body['timezone_information']).to be(nil)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq([nil, nil])
      end
    end

    describe 'PUT update' do
      it 'deleted bad timezones when updating the requested user_account\'s preferences' do
        old_values = ['Australia - Sydney', user_bad_tz.rails_tz]

        post_json = { "volume": 1, "muted": false, "auto_play": false, "visualize": {
          "hide_images": true,
          "hide_fixed": false
        } }

        response = put :modify_preferences, params: { user_account: post_json, format: :json }
        expect(response).to have_http_status(:ok)

        user_good_tz = User.find(user_bad_tz.id)
        new_values = [user_good_tz.tzinfo_tz, user_good_tz.rails_tz]

        expect(old_values).to_not eq(new_values)
        expect(new_values).to eq([nil, nil])
      end
    end
  end
end
