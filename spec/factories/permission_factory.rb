FactoryGirl.define do

  after(:build) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "Built #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }
  after(:create) { |object|
    is_blank = object.respond_to?(:creator) && object.creator.blank? && !object.is_a?(User)
    Rails.logger.warn "Created #{is_blank ? '[blank]' : ''} [#{object.object_id}] #{object.inspect}"
  }

  factory :permission do

    level { %w(reader writer).sample }

    trait :reader do
      level 'reader'
    end

    trait :writer do
      level 'writer'
    end

    # The only downside of this is that the associations will use the create strategy regardless of what strategy you're
    # building permission with, which essentially means that attributes_for and build_stubbed won't work correctly
    # for the permission factory.
    # http://stackoverflow.com/questions/10434572/pass-parameter-in-setting-attribute-on-association-in-factorygirl

    creator
    user # this is the user for which the permission is checked
    project {
      create(:project, creator: creator)
    }

    trait :with_sites_and_datasets do
      project {
        create(:project_with_sites_and_datasets, creator: creator)
      }
    end

    factory :read_permission, traits: [:reader, :with_sites_and_datasets]
    factory :write_permission, traits: [:writer, :with_sites_and_datasets]
  end
end