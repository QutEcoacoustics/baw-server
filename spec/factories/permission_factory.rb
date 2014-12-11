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
    creator
    user
    project
    level { ['reader', 'writer', 'owner'].sample }
  end

  factory :read_permission, class: Permission do
    level 'reader'
    creator
    user # this is the user for which the permission is checked
    association :project, factory: :project_with_sites_and_datasets
  end

  factory :write_permission, class: Permission do
    level 'writer'
    creator
    user # this is the user for which the permission is checked
    association :project, factory: :project_with_sites_and_datasets
  end

  factory :own_permission, class: Permission do
    level 'owner'
    creator
    user # this is the user for which the permission is checked
    association :project, factory: :project_with_sites_and_datasets
  end
end