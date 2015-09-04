include ActionDispatch::TestProcess

FactoryGirl.define do

  factory :script do
    sequence(:name) { |n| "script name #{n}"}
    sequence(:description) { |n| "script description #{n}" }
    sequence(:analysis_identifier) { |n| "script machine identifier #{n}"}
    sequence(:version) { |n| n * 0.01}
    sequence(:executable_command) { |n| "executable command #{n}"}
    sequence(:executable_settings) { |n| "executable settings #{n}"}

    creator

    trait :verified do
      verified true
    end
  end
end