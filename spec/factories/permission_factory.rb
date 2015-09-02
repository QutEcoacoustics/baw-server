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
    level { %w(reader writer).sample }
    user

    creator

    trait :reader do
      level 'reader'
    end

    trait :writer do
      level 'reader'
    end

    after(:build) do |permission, evaluator|
      if permission.project.blank?
        permission.project = FactoryGirl.create(:project_with_sites_and_saved_searches, creator: evaluator.creator)
      end
    end

    factory :read_permission, traits: [:reader]
    factory :write_permission, traits: [:writer]

  end

end