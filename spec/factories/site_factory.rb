FactoryGirl.define do

  factory :site do
    sequence(:name) { |n| "site name #{n}" }
    sequence(:notes) { |n|  "note number #{n}" }
    sequence(:description) { |n| "site description #{n}" }

    association :creator

    trait :site_with_lat_long do
      # Random.rand returns "a random integer greater than or equal to zero and less than the argument"
      # between -90 and 90 degrees
      latitude { Random.rand_incl(180.0) - 90.0 }
      # -180 and 180 degrees
      longitude { Random.rand_incl(360.0) - 180.0 }
    end

    after(:build) do |site|
      site.projects << build(:project) if site.projects.size < 1
    end

    factory :site_with_lat_long, traits: [:site_with_lat_long]
  end
end