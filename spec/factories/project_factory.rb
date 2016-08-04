FactoryGirl.define do

  factory :project do
    sequence(:name) { |n| "gen_project#{n}" }
    sequence(:description) { |n| "project description #{n}" }
    sequence(:urn) { |n| "urn:project:example.org/project/#{n}" }
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
      end
    end

    trait :with_saved_searches do
      transient do
        saved_search_count 1
      end
      after(:create) do |project, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        evaluator.saved_search_count.times do
          project.saved_searches << FactoryGirl.create(:saved_search_with_analysis_jobs, creator: evaluator.creator)
        end
      end
    end

    factory :project_with_sites, traits: [:with_sites]
    factory :project_with_sites_and_saved_searches, traits: [:with_sites, :with_saved_searches]

  end
end