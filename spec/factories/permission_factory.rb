FactoryGirl.define do

  after(:build) { |object|
    if object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
      Rails.logger.warn "Built #{object.inspect}"
    end
  }
  after(:create) { |object|
    if object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
      Rails.logger.warn "Created #{object.inspect}"
    end
  }

  factory :permission do
    creator
    user
    association :project, factory: :project
    level { ['reader', 'writer'].sample }
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
end