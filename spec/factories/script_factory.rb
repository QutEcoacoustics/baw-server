include ActionDispatch::TestProcess

FactoryGirl.define do

  factory :script do
    sequence(:name) { |n| "script name #{n}"}
    sequence(:analysis_identifier) { |n| "identifier #{n}"}
    sequence(:version) { |n| n * 0.01}
    sequence(:notes) { |n|  "note number #{n}" }
    sequence(:description) { |n| "script description #{n}" }

    # this will be slow
    settings_file { fixture_file_upload(Rails.root.join('public', 'files','script', 'settings_file.txt'), 'text/plain') }

    association :creator

    trait :verified do
      verified true
    end

    trait :data do
      data_file { fixture_file_upload(Rails.root.join('public', 'files','script', 'settings_file.txt'), 'text/plain') }
    end

  end
end