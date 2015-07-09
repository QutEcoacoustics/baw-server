FactoryGirl.define do

  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:annotation_name) { |n| "annotation name #{n}" }
    sequence(:script_settings) { |n|  {job_settings: "number #{n}"}.to_json }
    sequence(:description) { |n| "job description #{n}" }

    creator
    script
    saved_search

  end
end