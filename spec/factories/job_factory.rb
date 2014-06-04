FactoryGirl.define do

  factory :job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:annotation_name) { |n| "annotation name #{n}" }
    sequence(:script_settings) { |n|  {job_settings: "number #{n}"} }
    sequence(:description) { |n| "job description #{n}" }

    association :creator
    association :script
    association :dataset

  end
end