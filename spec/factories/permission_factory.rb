require 'faker'

FactoryGirl.define do

  after(:build) { |object| Rails.logger.debug "Built #{object.inspect}" }
  after(:create) { |object| Rails.logger.debug "Created #{object.inspect}" }

  factory :permission do
    creator
    user
    project
    level 'reader'
  end

  factory :read_permission, class: Permission do
    level { 'reader' }
    creator
    user # this is the user for which the permission is checked
    association :project, factory: :project_with_sites_and_datasets
  end

  factory :write_permission, class: Permission do
    level { 'writer' }
    creator
    user # this is the user for which the permission is checked
    association :project, factory: :project_with_sites_and_datasets
  end
end