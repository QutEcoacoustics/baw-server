FactoryGirl.define do

  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:annotation_name) { |n| "annotation name #{n}" }
    sequence(:custom_settings) { |n| "custom settings #{n}" }
    sequence(:description) { |n| "job description #{n}" }

    started_at { Time.zone.now }
    overall_status 'new'
    overall_status_modified_at { Time.zone.now}
    overall_progress { { queued: 1, working: 0, success: 0, failed: 0, total: 1}.to_json }
    overall_progress_modified_at { Time.zone.now}
    overall_count 1
    overall_duration_seconds 60

    creator
    script
    saved_search
    
    trait :overall_status_completed do
      overall_status 'completed'
    end

  end
end