require 'faker'

FactoryGirl.define do

  factory :project do
    sequence(:name) { |n| "#{Faker::Name.title}#{n}" }
    creator
    owner

    trait :urn do
      sequence(:urn) { |n| "urn:project:ecosounds.org/project/#{n}" }
    end

    trait :description do
      description { Faker::Lorem.paragraph }
    end

    trait :notes do
      notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    end

    trait :image do
      image_file { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user_spanhalf.png'), 'image/png') }
    end

    trait :with_sites do
      ignore do
        site_count 5
      end
      after(:create) do |project, evaluator|
        evaluator.site_count.times do
          project.sites << FactoryGirl.create(:site_with_audio_recordings)
        end
        #create_list(:site, evaluator.site_count, project: project)
      end
    end

    trait :with_datasets do
      ignore do
        dataset_count 5
      end
      after(:create) do |project, evaluator|
        create_list(:dataset, evaluator.dataset_count, project: project)
      end
    end

    factory :project_with_sites, traits: [:with_sites]
    factory :project_with_sites_and_datasets, traits: [:with_sites, :with_datasets]

  end
end