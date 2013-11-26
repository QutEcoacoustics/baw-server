require 'faker'

FactoryGirl.define do

  sequence(:user_counter)

  factory :unconfirmed_user, class: User do
    user_name { Faker::Internet.user_name + generate(:user_counter).to_s }
    email { Faker::Internet.email + generate(:user_counter).to_s}
    password {Faker::Lorem.words(6).join(' ')}
    authentication_token { SecureRandom.urlsafe_base64(nil, false) }
    factory :confirmed_user do
      after(:create) { |user| user.confirm! } #confirmed_at { Time.zone.now }
      factory :user do
        roles_mask { 2 } # user role
      end
      factory :admin do
        roles_mask { 1 } # admin role
      end
      factory :harvester do
        roles_mask { 4 } # harvester role
      end
    end
  end

end