# frozen_string_literal: true

# == Schema Information
#
# Table name: permissions
#
#  id              :integer          not null, primary key
#  allow_anonymous :boolean          default(FALSE), not null
#  allow_logged_in :boolean          default(FALSE), not null
#  level           :string           not null
#  created_at      :datetime
#  updated_at      :datetime
#  creator_id      :integer          not null
#  project_id      :integer          not null
#  updater_id      :integer
#  user_id         :integer
#
# Indexes
#
#  index_permissions_on_creator_id           (creator_id)
#  index_permissions_on_project_id           (project_id)
#  index_permissions_on_updater_id           (updater_id)
#  index_permissions_on_user_id              (user_id)
#  permissions_project_allow_anonymous_uidx  (project_id,allow_anonymous) UNIQUE WHERE (allow_anonymous IS TRUE)
#  permissions_project_allow_logged_in_uidx  (project_id,allow_logged_in) UNIQUE WHERE (allow_logged_in IS TRUE)
#  permissions_project_user_uidx             (project_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  permissions_creator_id_fk  (creator_id => users.id)
#  permissions_project_id_fk  (project_id => projects.id) ON DELETE => cascade
#  permissions_updater_id_fk  (updater_id => users.id)
#  permissions_user_id_fk     (user_id => users.id)
#
FactoryBot.define do
  # after(:build) { |object|
  #   is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
  #   Rails.logger.warn "After build #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  # }
  #
  # before(:create) { |object|
  #   is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
  #   Rails.logger.warn "Before create #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  # }
  #
  # after(:create) { |object|
  #   is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
  #   Rails.logger.warn "After create #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  # }
  #
  # before(:stub) { |object|
  #   is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
  #   Rails.logger.warn "Before stub #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  # }

  factory :permission do
    user
    project
    allow_logged_in { false }
    allow_anonymous { false }

    creator

    trait :reader do
      level { 'reader' }
    end

    trait :writer do
      level { 'writer' }
    end

    trait :owner do
      level { 'owner' }
    end

    trait :allow_anonymous do
      user { nil }
      allow_anonymous { true }
    end

    trait :allow_logged_in do
      user { nil }
      allow_logged_in { true }
    end

    factory :read_permission, traits: [:reader]
    factory :write_permission, traits: [:writer]
    factory :own_permission, traits: [:owner]

    factory :read_anon_permission, traits: [:reader, :allow_anonymous]
    factory :read_logged_in_permission, traits: [:reader, :allow_logged_in]
    factory :write_logged_in_permission, traits: [:writer, :allow_logged_in]
  end
end
