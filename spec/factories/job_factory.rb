require 'faker'

FactoryGirl.define do

  factory :job do
    name {Faker::Name.title}
    annotation_name {Faker::Lorem.word}
    script_settings { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    association :creator, factory: :user
    association :script, factory: :script
    association :dataset, factory: :dataset
  end
end