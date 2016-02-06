FactoryGirl.define do

  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:custom_settings) { |n| "custom settings #{n}" }

    creator
    saved_search

    overall_progress { { queued: 1, working: 0, success: 0, failed: 0, total: 1}.to_json }
    overall_count 1
    overall_duration_seconds 60

    started_at { Time.zone.now }
    overall_status_modified_at { Time.zone.now }
    overall_progress_modified_at { Time.zone.now }

    after(:build) do |analysis_job, evaluator|
      if analysis_job.script.blank?
        analysis_job.script = FactoryGirl.create(:script, creator: evaluator.creator)
      end
    end

  end
end