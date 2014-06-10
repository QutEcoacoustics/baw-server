FactoryGirl.define do

  after(:build) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "After build #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }

  before(:create) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "Before create #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }

  after(:create) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "After create #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }

  before(:stub) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "Before stub #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }

  factory :permission do

    # attributes
    level 'reader'

    # associations
    association :creator
    association :user # this is the user for which the permission is checked
    association :project

    # traits
    trait :write do
      level 'writer'
    end

    trait :read do
      level 'reader'
    end

    # other factories
    factory :write_permission, traits: [:write]
    factory :read_permission, traits: [:read]
  end

end