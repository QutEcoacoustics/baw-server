require 'faker'

FactoryGirl.define do
  factory :bookmark do
    offset_seconds { Random.rand(86401.0) }
    description { Faker::Lorem.word }

    user
    audio_recording

    trait :name do
      sequence(:name) { |n| "#{Faker::Name.title}#{n}" }
    end

  end
end

