# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:custom_settings) { |n| "custom settings #{n}" }
    sequence(:description) { |n| "job description #{n}" }

    creator
    saved_search
    script

    overall_progress { { queued: 1, working: 0, success: 0, failed: 0, total: 1 }.to_json }
    overall_count { 1 }
    overall_duration_seconds  { 60 }
    overall_data_length_bytes { 1024 }

    started_at { Time.zone.now }

    # should be set by the workflow
    #overall_status_modified_at { Time.zone.now }
    overall_progress_modified_at { Time.zone.now }

    factory :analysis_job_with_valid_saved_search do
      association :saved_search, factory: :saved_search_with_projects
    end
  end
end
