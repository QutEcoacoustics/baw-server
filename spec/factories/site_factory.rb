require 'faker'

FactoryGirl.define do
  # factory generally used to create attributes for POST requests
  # to create an site with all dependencies, check permission_factory.rb
  factory :required_site_attributes, class: Site do
    name {Faker::Name.title}
    latitude Random.rand(180) - 90
    longitude Random.rand(360) - 180

    factory :all_site_attributes, class: Site do
      notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
      factory :site do
        association :creator, factory: :user
      end
    end
  end
end