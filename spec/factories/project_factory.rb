require 'faker'

FactoryGirl.define do
  factory :required_project_attributes, class: Project do
    name            { Faker::Name.title }
    sequence(:urn)  {|n| "urn:project:ecosounds.org/project/#{n}" }
    factory :all_project_attributes, class: Project do
      description     { Faker::Lorem.sentences(2).join(' ') }
      notes           { { Faker::Lorem.word => Faker::Lorem.paragraph } }
      factory :project do
        association :creator, factory: :user
      end
    end
  end
end