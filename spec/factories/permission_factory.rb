FactoryGirl.define do

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
    allow_logged_in false
    allow_anonymous false

    creator

    trait :reader do
      level 'reader'
    end

    trait :writer do
      level 'writer'
    end

    trait :owner do
      level 'owner'
    end

    trait :allow_anonymous do
      user nil
      allow_anonymous true
    end

    trait :allow_logged_in do
      user nil
      allow_logged_in true
    end

    after(:build) do |permission, evaluator|
      if permission.project.blank?
        permission.project = FactoryGirl.create(:project_with_sites_and_saved_searches, creator: evaluator.creator)
      end
    end

    factory :read_permission, traits: [:reader]
    factory :write_permission, traits: [:writer]
    factory :own_permission, traits: [:owner]

    factory :read_anon_permission, traits: [:reader, :allow_anonymous]
    factory :read_logged_in_permission, traits: [:reader, :allow_logged_in]
    factory :write_logged_in_permission, traits: [:writer, :allow_logged_in]
  end

end