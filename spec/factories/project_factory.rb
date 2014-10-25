FactoryGirl.define do

  factory :project do
    sequence(:name) { |n| "project#{n}" }
    sequence(:description) { |n| "project description #{n}" }
    sequence(:urn) { |n| "urn:project:ecosounds.org/project/#{n}" }
    sequence(:notes) { |n|  "note number #{n}" }

    creator

    trait :image do
      image_file { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user_spanhalf.png'), 'image/png') }
    end

    trait :with_sites do
      transient do
        site_count 1
      end
      after(:create) do |project, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        evaluator.site_count.times do
          project.sites << FactoryGirl.create(:site_with_audio_recordings, creator: evaluator.creator)
        end
        #create_list(:site, evaluator.site_count, project: project)
      end
    end

    trait :with_datasets do
      transient do
        dataset_count 1
      end
      after(:create) do |project, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:dataset, evaluator.dataset_count, project: project, creator: evaluator.creator)
      end
    end

    factory :project_with_sites, traits: [:with_sites]
    factory :project_with_sites_and_datasets, traits: [:with_sites, :with_datasets]

  end
end