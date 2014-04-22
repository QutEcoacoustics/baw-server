require 'faker'

FactoryGirl.define do

  factory :dataset do
    sequence(:name) { |n| "dataset name#{n}" }
    creator
    project

    trait :description do
      description { Faker::Lorem.word }
    end

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
      type_of_tag Tag::AVAILABLE_TYPE_OF_TAGS.sample(2)
    end

    trait :description do
      description { Faker::Lorem.word }
    end

    trait :tag_text_filters do
      tag_text_filters ['a tag', 'my other tag', 'the-next-tag']
    end

    trait :with_jobs do
      ignore do
        job_count 1
      end
      after(:create) do |dataset, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:job, evaluator.dataset_count, dataset: dataset, creator: evaluator.creator)
      end
    end

    trait :with_sites do
      ignore do
        site_count 1
      end
      after(:create) do |dataset, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:site, evaluator.site_count, dataset: dataset, creator: evaluator.creator)
      end
    end
  end
end