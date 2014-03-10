require 'faker'

FactoryGirl.define do

  factory :unconfirmed_user, class: User do
    sequence(:user_name) { |n| "#{Faker::Internet.user_name}#{n}" }
    sequence(:email) { |n| "#{n}#{Faker::Internet.email}" }

    password { Faker::Lorem.words(6).join(' ') }
    authentication_token { SecureRandom.urlsafe_base64(nil, false) }
    roles_mask { 2 } # user role

    trait :confirmed do
      after(:create) do |user|
        #confirmed_at { Time.zone.now }
        user.confirm!
      end
    end

    trait :admin_role do
      roles_mask { 1 } # admin role
    end

    trait :harvester_role do
      roles_mask { 4 } # harvester role
    end

    trait :saved_preferences do
      preferences { {someSettingOrOther: [1, 2, 5], ImAnotherOne: 'hello!'}.to_json }
    end

    trait :avatar_image do
      # this will be slow
      image { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user-512.png'), 'image/png') }
    end

    factory :confirmed_user, traits: [:confirmed], aliases: [:user, :creator, :owner, :updater, :deleter, :uploader]
    factory :admin, traits: [:confirmed, :admin_role]
    factory :harvester, traits: [:confirmed, :harvester_role]
    factory :user_with_preferences, traits: [:confirmed, :saved_preferences]

  end

end