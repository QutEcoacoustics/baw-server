# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                                                                              :integer          not null, primary key
#  authentication_token                                                            :string
#  confirmation_sent_at                                                            :datetime
#  confirmation_token                                                              :string
#  confirmed_at                                                                    :datetime
#  contactable(Is the user contactable - consent status re: email communications ) :enum             default("unknown"), not null
#  current_sign_in_at                                                              :datetime
#  current_sign_in_ip                                                              :string
#  email                                                                           :string           not null
#  encrypted_password                                                              :string           not null
#  failed_attempts                                                                 :integer          default(0)
#  image_content_type                                                              :string
#  image_file_name                                                                 :string
#  image_file_size                                                                 :bigint
#  image_updated_at                                                                :datetime
#  invitation_token                                                                :string
#  last_seen_at                                                                    :datetime
#  last_sign_in_at                                                                 :datetime
#  last_sign_in_ip                                                                 :string
#  locked_at                                                                       :datetime
#  preferences                                                                     :text
#  rails_tz                                                                        :string(255)
#  remember_created_at                                                             :datetime
#  reset_password_sent_at                                                          :datetime
#  reset_password_token                                                            :string
#  roles_mask                                                                      :integer
#  sign_in_count                                                                   :integer          default(0)
#  tzinfo_tz                                                                       :string(255)
#  unconfirmed_email                                                               :string
#  unlock_token                                                                    :string
#  user_name                                                                       :string           not null
#  created_at                                                                      :datetime
#  updated_at                                                                      :datetime
#
# Indexes
#
#  index_users_on_authentication_token  (authentication_token) UNIQUE
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  users_user_name_unique               (user_name) UNIQUE
#
FactoryBot.define do
  factory :unconfirmed_user, class: 'User' do
    sequence(:user_name) { |n| "unconfirmed_user #{n}" }
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
      email { 'harvester@example.com' }
      password { 'password' }
      roles_mask { 4 } # harvester role
    end

    trait :saved_preferences do
      preferences { { someSettingOrOther: [1, 2, 5], ImAnotherOne: 'hello!' }.to_json }
    end

    trait :avatar_image do
      # this will be slow
      image { fixture_file_upload(Rails.public_path.join('images/user/user-512.png'), 'image/png') }
    end

    factory :confirmed_user, traits: [:confirmed], aliases: [:user, :creator, :updater, :deleter, :uploader, :flagger]
    factory :admin, traits: [:confirmed, :admin_role]
    factory :harvester, traits: [:confirmed, :harvester_role]
    factory :user_with_preferences, traits: [:confirmed, :saved_preferences]
  end
end
