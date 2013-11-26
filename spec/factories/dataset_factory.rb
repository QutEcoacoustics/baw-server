require 'faker'

FactoryGirl.define do
  # factory generally used to create attributes for POST requests
  # to create a dataset with all dependencies, check permission_factory.rb
  factory :required_dataset_attributes, class: Dataset do
    name {Faker::Name.title}
    association :creator, factory: :user
    association :project, factory: :project

    factory :all_dataset_attributes, class: Dataset do
      start_time '06:30'
      end_time '11:45'
      start_date '2013-11-06'
      end_date '2013-11-09'
      filters nil
      number_of_samples nil
      number_of_tags [nil, 0, 1].sample
      types_of_tags [nil, :human, :computer].sample
      description { Faker::Lorem.paragraph }
      factory :dataset do

      end
    end
  end
end