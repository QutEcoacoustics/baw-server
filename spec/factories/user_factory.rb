FactoryGirl.define do

  factory :unconfirmed_user, class: User do
    sequence(:user_name) { |n| "unconfirmed_user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:authentication_token) { |n| "some random token #{n}" }
    sequence(:password) { |n| "password #{n}" }

    roles_mask { 2 } # user role

    # after(:create) do |user|
    #   Rails.logger.warn "Created #{user.inspect}"
    # end
    #
    # after(:build) do |user|
    #   Rails.logger.warn "Built #{user.inspect}"
    # end

    trait :confirmed do

      sequence(:user_name) { |n| "confirmed_user #{n}" }
      after(:build) do |user|
        user.confirmation_token = nil
        user.skip_confirmation!
      end
    end

    trait :admin_role do
      sequence(:user_name) { |n| "admin_user #{n}" }
      roles_mask { 1 } # admin role
    end

    trait :harvester_role do
      sequence(:user_name) { |n| "harvester_user #{n}" }
      roles_mask { 4 } # harvester role
    end

    trait :saved_preferences do
      preferences { {someSettingOrOther: [1, 2, 5], ImAnotherOne: 'hello!'}.to_json }
    end

    trait :avatar_image do
      # this will be slow
      image { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user-512.png'), 'image/png') }
    end

    factory :confirmed_user, traits: [:confirmed], aliases: [:user, :creator, :updater, :deleter, :uploader, :flagger]
    factory :admin, traits: [:confirmed, :admin_role]
    factory :harvester, traits: [:confirmed, :harvester_role]
    factory :user_with_preferences, traits: [:confirmed, :saved_preferences]

  end

end