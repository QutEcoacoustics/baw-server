FactoryGirl.define do

  factory :saved_search do
    sequence(:name) { |n| "saved search name #{n}" }
    sequence(:description) { |n| "saved search description #{n}" }
    sequence(:stored_query) { |n| {uuid: {eq: 'blah blah'}} }

    creator

    trait :with_analysis_jobs do
      transient do
        analysis_job_count 1
      end
      after(:create) do |saved_search, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:analysis_job, evaluator.analysis_job_count, saved_search: saved_search, creator: evaluator.creator)
      end
    end

    factory :saved_search_with_analysis_jobs, traits: [:with_analysis_jobs]

  end
end