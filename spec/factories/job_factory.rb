require 'faker'

FactoryGirl.define do

  factory :job do
    sequence(:name) { |n| "#{Faker::Name.title}#{n}" }
    annotation_name {Faker::Lorem.word}
    script_settings { {Faker::Lorem.word => Faker::Lorem.word} }

    creator
    script
    dataset

    trait :description do
      description { Faker::Lorem.word }
    end

  end
end