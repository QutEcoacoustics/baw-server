FactoryGirl.define do

  factory :dataset do
    sequence(:name) { |n| "dataset name#{n}" }
    sequence(:description) { |n| "description #{n}" }

    association :creator
    association :project

    trait :start_time do
      start_time '06:30'
    end

    trait :end_time do
      end_time '11:45'
    end

    trait :start_date do
      start_date '2013-11-06'
    end

    trait :end_date do
      end_date '2013-11-09'
    end

    trait :number_of_samples do
      number_of_samples 100
    end

    trait :number_of_tags do
      number_of_tags 1
    end

    trait :random_type do
      type_of_tag { Tag::AVAILABLE_TYPE_OF_TAGS.sample(2) }
    end

    trait :tag_text_filters do
      tag_text_filters ['a tag', 'my other tag', 'the-next-tag']
    end

    after(:build) do |dataset|
      dataset.sites << build(:dataset) if dataset.sites.size < 1
    end

  end
end